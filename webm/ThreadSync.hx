package webm;

import cpp.vm.Thread;

typedef ThreadMessage = {
    var id:Int;
    var type:Int;
    var data:Dynamic;
}

@:enum
abstract ThreadMessageReceived(Int) from Int to Int {
    var MAIN_THREAD = 1;
    var PARAMS      = 2;
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
        var messageDynamic:Dynamic = Thread.readMessage(false);
        var message:ThreadMessage = messageDynamic;
        if (message != null) {
            if (threads.exists(message.id)) {
                var thread = threads.get(message.id);
                thread.sent(message.type, message.data);
            } else {
                // TODO: Re-send the message in hope it will get catched by the proper class????
                trace('Received Message from Main Thread but Process was killed? ${message.id}');
            }
        } else {
            // TODO: Re-send the message in hope it will get catched by the proper class????
            if (message == null && messageDynamic != null) trace('Received Invalid Message from Main Thread');
        }
    }

    public static function create(params:Dynamic, init:(Int->Dynamic->Void)->Dynamic->(Int->Dynamic->Bool), sent:Int->Dynamic->Void, dispose:Void->Void) {
        ThreadSync.init();
        
        var thread = new ThreadProcess(ThreadSync.id++);
        threads.set(thread.id, thread);

        return thread.create(params, init, sent, function() {
            thread.clean();
            threads.remove(thread.id);
            dispose();
        });
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
        thread = null;
        sent = null;

        trace('Thread $id killed!');
    }

    public function create(params:Dynamic, init:(Int->Dynamic->Void)->Dynamic->(Int->Dynamic->Bool), sent:Int->Dynamic->Void, dispose:Void->Void) {
        var id = this.id;

        // TODO: Should trace be sent to Main Thread!?!?!?!?
        trace('Thread $id started!');

        this.sent = sent;
        thread = Thread.create(function() {
            try {
                // Get main Thread
                function readMessage(type:Int) {
                    var message:ThreadMessage = Thread.readMessage(true);
                    if (message != null) {
                        if (message.id == id && message.type == type) {
                            return message.data;
                        } else {
                            trace('Received valid message but of ${message.type != type ? 'wrong type ${message.type}' : ''} ${message.id != id ? 'wrong id ${message.id}' : ''}');
                        }
                    } else {
                        trace('Received invalid message to Thread Process ${id}');
                    }

                    return null;
                } 

                var main = readMessage(MAIN_THREAD);
                if (main != null) {
                    var params = readMessage(PARAMS);
                    if (params != null) {
                        var received = init(function(type, data) {
                            main.sendMessage({id: id, type: type, data: data});
                        }, params);

                        // Listeners
                        var done = false;

                        // Process websocket
                        var i = 0;
                        while(!done) {
                            Sys.sleep(0.1);

                            // Read message from current thread, stop if we get "close" otherwise send message to Socket
                            var msgDynamic:Dynamic = Thread.readMessage(false);
                            var msg:ThreadMessage = msgDynamic;
                            if (msg != null) {
                                if (msg.id == id) {
                                    if (received(msg.type, msg.data)) done = true;
                                } else {
                                    trace('Message Sent to wrong Thread Process ${id}');
                                }
                            } else {
                                if (msg == null && msgDynamic != null) trace('Invalid Message sent to Thread Process ${id}');
                            }
                        }
                    } else {
                        trace('Invalid Params sent to Thread Process ${id}');
                    }
                } else {
                        trace('Invalid Main Thread sent to Thread Process ${id}');
                    }
            } catch (e:Dynamic) {
                // TODO: Maybe tell the class handling the processs about the error?
                trace('Catched error during processing of Thread Process ${id}', e);
            }

            dispose();
        });

        thread.sendMessage({id: id, type: MAIN_THREAD, data: Thread.current()});
        thread.sendMessage({id: id, type: PARAMS, data: params});

        return this;
    }
}