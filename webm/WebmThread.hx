package webm;

#if (sys && !neko && !disableThread2)
import cpp.vm.Thread;
#end

import haxe.ds.Option;
import haxe.io.Bytes;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.utils.ByteArray;
import openfl.Lib;
import webm.*;

@:enum
abstract WebmThreadId(Int) from Int to Int {
    var Frame = 100;
    var Close = 101;
    var Error = 102;
    var Info  = 103;
}

@:enum
abstract WebmThreadAction(Int) from Int to Int {
    var Play = 100;
    var Stop = 101;
}

typedef WebmThreadMessage = {
    var id:WebmThreadId;
    @:optional var bytes:Bytes;
    @:optional var data:Dynamic;
}

@:access(webm.WebmPlayer)
class WebmThread extends Bitmap {

    #if (sys && !neko && !disableThread2)
    var thread:Thread;
    #else
    var webm:WebmPlayer;
    #end

    public static function create(path:String) {
        var webm = new WebmThread(path);
        return webm;
    }

    public function new(path:String) {
        super();

        #if (sys && !neko && !disableThread2)
        thread = Thread.create(createWebm);
        thread.sendMessage(Thread.current());
        thread.sendMessage(path);

        trace('WEBM THREAD');

        // Listens for messages on Thread and broadcast them through Signals
        Lib.current.stage.addEventListener(Event.ENTER_FRAME, function(e) {
            var message:WebmThreadMessage = Thread.readMessage(false); // TODO: Should this be sent to other thread class as well ?
            if (message != null) switch(message.id) {
                case Info  : 
                    trace('!!!', message.data.width2, message.data.width2);
                    bitmapData = new BitmapData(message.data.width2, message.data.width2, true, 0x00000000);
                case Close : //onClose.dispatch();
                case Error : //onError.dispatch();
                case Frame : onFrame(message.bytes);
            }
        });
        #else
        // Create WebSocket object
        webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
            onFrame(bytes);
        });
        #end

        // Close on error, destroy on close
        //onError.add(close);
        //onClose.add(destroy);
    }

    public function play() {

    }

    function onFrame(bytes) {
        var byteArray:ByteArray = ByteArray.fromBytes(bytes);

        bitmapData.lock();
        bitmapData.setPixels(bitmapData.rect, byteArray);
        bitmapData.unlock();
    }

    public function stop() {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Stop);
        #else
        webm.stop();
        webm.dispose();
        #end

        //onClose.dispatch();
    }

    public function destroy() {
        // Destroy all signals
        //onFrame.destroy();
        //onClose.destroy();
        //onError.destroy();
        //frameListener.destroy();

        // Stop
        stop();

        #if (sys && !neko && !disableThread2)
        // Makes sure we didn't left any messages in the Thread Queue
        while(Thread.readMessage(false) != null) {};
        #end
    }

    #if (sys && !neko && !disableThread2)
    function createWebm() {
        // Get main Thread
        var main = Thread.readMessage(true);
        var path = Thread.readMessage(true);
        
        try {
            // Create WebSocket object
            var webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
                main.sendMessage({id: Frame, data: null, bytes: bytes});
            });

            main.sendMessage({id: Info, data: { width: webm.width2, height: webm.height2 }, bytes: null});

            // Listeners
            var done = false;

            // Process websocket
            var i = 0;
            while(!done) {
                Sys.sleep(0.1);

                // Read message from current thread, stop if we get "close" otherwise send message to Socket
                var msg:String = Thread.readMessage(false);
                if (msg != null) {
                    if (Std.parseInt(msg) == Stop) done = true;
                }
            }

            // If we're out of the loop then we're done here and clean up
            webm.stop();
            webm.dispose();
        } catch (e:Dynamic) {
            main.sendMessage({id: Error, data: null, bytes: null});
        }
    }
    #end
}
