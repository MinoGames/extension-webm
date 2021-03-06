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

#if (sys && !neko)
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

    #if (sys && !neko)
    var thread:ThreadProcess;
    #end

    var webm:WebmPlayer;
    
    public var useThread = true;

    public var lastRequestedVideoFrame:Float = 0;
    public var frameRate:Float = 24;
    public var duration:Float = 5;

    public var loaded:Void->Void = null;
    var firstFrame = false;

    public static function create(path:String, useThread:Bool = true) {
        var webm = new WebmThread(path, useThread);
        return webm;
    }

    public function getId() {
        return if (this.useThread) {
            #if (sys && !neko)
            thread.id;
            #else
            -1;
            #end
        } else {
            -1;
        }
    }

    public function new(path:String, useThread:Bool = true) {
        super(null, PixelSnapping.AUTO, true);

        #if (sys && !neko && !disableThread2)
        this.useThread = useThread;
        #else
        this.useThread = false;
        #end

        trace('-------------- USE THREAD: ${useThread}');

        if (this.useThread) {
            #if (sys && !neko)
            thread = ThreadSync.create(path, function(sendMessage, path, close) {
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
                    case Frame : 
                        if (bitmapData != null) onFrame(cast data);

                        if (!firstFrame) {
                            firstFrame = true;
                            if (loaded != null) {
                                loaded();
                                loaded = null;
                            }
                        }
                    case -1:
                        // TODO: Too agressive?
                        if (bitmapData != null) bitmapData.dispose();
                }
                // -- Sent
            });
            #end
        } else {
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
        }
    }

    function enterFrameHandler(e) {
        if (!this.useThread) {
            webm.process();
            lastRequestedVideoFrame = webm.lastRequestedVideoFrame;
        }
    }

    public function play() {
        if (this.useThread) {
            #if (sys && !neko)
            thread.sendMessage(Play, {});
            #end
        } else {
            webm.play();
        }
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
        if (this.useThread) {
            #if (sys && !neko)
            thread.sendMessage(Stop, {});
            #end
        } else {
            webm.stop();
            webm.dispose();
        }
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
