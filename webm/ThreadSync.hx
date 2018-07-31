package webm;

import cpp.vm.Thread;

typedef ThreadMessage = {
    var id:Int;
    var type:Int;
    var data:Dynamic;
}

@:enum
abstract ThreadMessageReceived(Int) from Int to Int {
    var MainThread  = -1;
    var Params      = 2;
    var Log         = 3;
    var Kill        = 4;
}

// Create new Thread and makes sure message are sent to the proper instance
class ThreadSync {

    static var id:Int = 1;
    static var initialized = false;
    static var threads:Map<Int, ThreadProcess> = new Map();

    function new() { }

    public static inline function init() {
        if (!initialized) {
            initialized = true;
            openfl.Lib.current.addEventListener(openfl.events.Event.ENTER_FRAME, enterFrame);
        }
    }

    static inline function enterFrame(e) {
        process();
    }

    // Call this every frame
    public static function process() {
        var messageRead = 0;
        var message:ThreadMessage = null;
        do {
            messageRead++;

            var messageDynamic:Dynamic = Thread.readMessage(false);
            message = messageDynamic;
            if (message != null) {
                if (message.id == MainThread) {
                    // Message for Main Thread
                    switch(message.type) {
                        case Log: 
                            trace('THREAD Log', message.data);
                        case Kill: 
                            trace('THREAD Kill', message.data);
                            if (threads.exists(message.data)) {
                                var thread = threads.get(message.data);
                                thread.clean();
                                threads.remove(message.data);
                            } else {
                                trace('THREAD already Killed?????', message.data);
                            }
                        default: 
                    }
                } else if (threads.exists(message.id)) {
                    var thread = threads.get(message.id);
                    thread.sent(message.type, message.data);
                } else {
                    trace('Received Message from Main Thread but Process was killed? ${message.id}');
                }
            } else {
                // TODO: Re-send the message in hope it will get catched by the proper class????
                if (message == null && messageDynamic != null) trace('Received Invalid Message from Main Thread');
            }
        } while(message != null);

        //trace('messageRead: $messageRead');
    }

    public static function create(params:Dynamic, init:(Int->Dynamic->Void)->Dynamic->{fps:Float, received: (Int->Dynamic->Bool), processed: Void->Void, disposed: Void->Void}, sent:Int->Dynamic->Void) {
        ThreadSync.init();
        
        var thread = new ThreadProcess(ThreadSync.id++);
        threads.set(thread.id, thread);

        trace('Thread ${thread.id} started!');

        return thread.create(params, init, sent);
    }
}

class ThreadProcess {
    public var id:Int;
    public var thread:Thread;
    public var sent:Int->Dynamic->Void;

    public function new(id:Int) {
        this.id = id;
    }

    public function sendMessage(type:Int, data:Dynamic) {
        if (thread != null) {
            thread.sendMessage({id: id, type: type, data: data});
        }
    }

    public function clean() {
        sent(-1, {});

        thread = null;
        sent = null;
    }

    public function create(params:Dynamic, init:(Int->Dynamic->Void)->Dynamic->{fps:Float, received: (Int->Dynamic->Bool), processed: Void->Void, disposed: Void->Void}, sent:Int->Dynamic->Void) {
        var id = this.id;

        this.sent = sent;
        thread = Thread.create(function() {
            var dispose = function() {};
            var process = function() {};
            var main:Thread = null;
            
            function log(message:String) {
                if (main != null) {
                    main.sendMessage({id: MainThread, type: Log, data: message});
                }
            }

            try {
                // Get main Thread
                function readMessage(type:Int):Dynamic {
                    var message:ThreadMessage = Thread.readMessage(true);
                    if (message != null) {
                        if (message.id == id && message.type == type) {
                            return message.data;
                        } else {
                            log('Received valid message but of ${message.type != type ? 'wrong type ${message.type}' : ''} ${message.id != id ? 'wrong id ${message.id}' : ''}');
                        }
                    } else {
                        log('Received invalid message to Thread Process ${id}');
                    }

                    return null;
                } 

                main = readMessage(MainThread);
                if (main != null) {
                    var params:String = readMessage(Params);
                    if (params != null) {
                        var handlers = init(function(type, data) {
                            main.sendMessage({id: id, type: type, data: data});
                        }, params);

                        var received = handlers.received;
                        dispose = handlers.disposed;
                        process = handlers.processed;
                        var fps = handlers.fps;

                        // Listeners
                        var done = false;

                        // Process
                        var i = 0;
                        while(!done) {
                            var timer = haxe.Timer.stamp();
                            
                            // Read message from current thread, stop if we get "close" otherwise send message to Socket
                            var msgDynamic:Dynamic = Thread.readMessage(false);
                            var msg:ThreadMessage = msgDynamic;
                            if (msg != null) {
                                if (msg.id == id) {
                                    if (received(msg.type, msg.data)) done = true;
                                } else {
                                    log('Message Sent to wrong Thread Process ${id}');
                                }
                            } else {
                                if (msg == null && msgDynamic != null) log('Invalid Message sent to Thread Process ${id}');
                            }

                            process();

                            // Sleep until frameRate
                            var diff = haxe.Timer.stamp() - timer;
                            var wait = 1 / fps;

                            if (wait > diff) Sys.sleep(wait - diff);
                        }
                    } else {
                        log('Invalid Params sent to Thread Process ${id}');
                    }
                } else {
                    log('Invalid Main Thread sent to Thread Process ${id}');
                }
            } catch (e:Dynamic) {
                // TODO: Maybe tell the class handling the processs about the error?
                log('Catched error during processing of Thread Process ${id}, ${e}');
            }

            log('Thread Process ${id} finished processing!');

            dispose();

            if (main != null) {
                main.sendMessage({id: MainThread, type: Kill, data: id});
            }
        });

        thread.sendMessage({id: id, type: MainThread, data: Thread.current()});
        thread.sendMessage({id: id, type: Params, data: params});

        return this;
    }
}