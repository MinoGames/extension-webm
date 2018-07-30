package webm;

import haxe.ds.Option;
import haxe.io.Bytes;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.PixelSnapping;
import openfl.events.Event;
import openfl.utils.ByteArray;
import openfl.Lib;
import webm.*;

#if (sys && !neko && !disableThread2)
import webm.ThreadSync;
#end

@:enum
abstract WebmSent(Int) from Int to Int {
    var Frame     = 100;
    var Info      = 103;
    var FrameInfo = 104;
}

@:enum
abstract WebmReceived(Int) from Int to Int {
    var Play      = 400;
    var Stop      = 401;
}

@:access(webm.WebmPlayer)
class WebmThread extends Bitmap {

    #if (sys && !neko && !disableThread2)
    var thread:ThreadProcess;
    #else
    var webm:WebmPlayer;
    #end

    public var lastRequestedVideoFrame:Float = 0;
    public var frameRate:Float = 24;
    public var duration:Float = 5;

    public var loaded:Void->Void = null;

    public static function create(path:String) {
        var webm = new WebmThread(path);
        return webm;
    }

    public function getId() {
        #if (sys && !neko && !disableThread2)
        return thread.id;
        #else
        return -1;
        #end
    }

    public function new(path:String) {
        super(null, PixelSnapping.AUTO, true);

        #if (sys && !neko && !disableThread2)
        thread = ThreadSync.create(path, function(sendMessage, path) {
            // Initialization

            // Create WebSocket object
            var webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
                sendMessage(Frame, bytes);
            });
            webm.play();

            sendMessage(Info, { width: webm.width, height: webm.height, frameRate: webm.frameRate, duration: webm.duration });

            return {
            fps: webm.frameRate,    
            received: function(type, data) {
                // Message Received from Thread
                return switch(type) {
                    case Play : 
                        webm.play();
                        false;
                    case Stop : 
                        webm.stop();
                        true;
                    default: 
                        false;
                }
                // -- Received
            }, processed: function() {
                webm.process();
                sendMessage(FrameInfo, { lastRequestedVideoFrame: webm.lastRequestedVideoFrame });
            }, disposed: function() {
                webm.dispose();
            }};
            // -- Initialization
        }, function(type:Int, data:Dynamic) {
            // Message Sent from Thread
            switch(type) {
                case FrameInfo:
                    lastRequestedVideoFrame = data.lastRequestedVideoFrame;
                case Info  : 
                    frameRate = data.frameRate;
                    duration = data.duration;

                    bitmapData = new BitmapData(data.width, data.height, true, 0x00000000);
                    smoothing = true;

                    if (loaded != null) loaded();
                case Frame : 
                    // Copy bytes
                    // TODO: Do it from the Thread instead???
                    
                    //var bytes = haxe.io.Bytes.alloc(data.length);
                    //bytes.blit(0, data, 0, data.length);

                    if (bitmapData != null) onFrame(cast data);
                    //if (bitmapData != null) onFrame(bytes);
                case -1:
                    // TODO: Too agressive?
                    if (bitmapData != null) bitmapData.dispose();
            }
            // -- Sent
        });
        #else
        // Create WebSocket object
        webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
            onFrame(bytes);
        });

        duration = webm.duration;
        frameRate = webm.frameRate;

        bitmapData = new BitmapData(webm.width, webm.height, true, 0x00000000);
        webm.play();

        addEventListener(Event.ENTER_FRAME, enterFrameHandler);
        // TODO: Add ENTER_FRAME for processing
        #end
    }

    function enterFrameHandler(e) {
        #if (sys && !neko && !disableThread2)
        
        #else
        webm.process();
        lastRequestedVideoFrame = webm.lastRequestedVideoFrame;
        #end
    }

    public function play() {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Play, {});
        #else
        webm.play();
        #end
    }

    function onFrame(bytes) {
        var byteArray:ByteArray = ByteArray.fromBytes(bytes);

        bitmapData.lock();
        bitmapData.setPixels(bitmapData.rect, byteArray);
        bitmapData.unlock();

        // TODO: Too aggressive?
        byteArray.clear();

        smoothing = true;
    }

    public function stop() {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Stop, {});
        #else
        webm.stop();
        webm.dispose();
        #end
    }

    public function dispose() {
        stop();

        loaded = null;

        // TODO: Too aggressive?
        if (bitmapData != null) bitmapData.dispose();
        bitmapData = null;

        removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
    }
}
