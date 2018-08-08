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

using Lambda;

@:enum
abstract MultiWebmSent(Int) from Int to Int {
    var Frame     = 200;
    var Info      = 203;
    var FrameInfo = 204;
}

@:enum
abstract MultiWebmReceived(Int) from Int to Int {
    var Play      = 500;
    var Stop      = 501;
    var Create    = 502;
}

typedef WebmDisplay = {
    webm:WebmPlayer, // null when using thread
    bitmap:Bitmap,
    frameRate:Float,
    duration:Float,
    width:Float,
    height:Float,
    firstFrame:Bool,
    lastRequestedVideoFrame:Float,
    loaded:Void->Void,
    id:Int
}

typedef WebmProcess = {
    webm:WebmPlayer,
    id:Int
}

@:access(webm.WebmPlayer)
class MultiWebmThread {

    static var id = 0;

    var webms:Map<Int, WebmDisplay>;

    #if (sys && !neko && !disableThread2)
    var thread:ThreadProcess;
    #end

    public static function create() {
        var webm = new MultiWebmThread();
        return webm;
    }

    public function getId() {
        #if (sys && !neko && !disableThread2)
        return thread.id;
        #else
        return -1;
        #end
    }

    public function createWebm(path:String, ?loaded:Void->Void) {
        var id = MultiWebmThread.id++;

        var bmp = new Bitmap(null, PixelSnapping.AUTO, true);
        var obj:WebmDisplay = {
            bitmap: bmp,
            webm: null,
            frameRate: 24,
            duration: 0,
            width: 1,
            height: 1,
            lastRequestedVideoFrame: 0,
            loaded: loaded,
            firstFrame: false,
            id: id
        };
        webms.set(id, obj);

        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Create, {id: id, path: path});
        #else
        var webm = new WebmPlayer(new WebmIoFile(path), false, true, function(bytes) {
            onFrame(obj, bytes);
        });

        bmp.bitmapData = new BitmapData(webm.width, webm.height, true, 0xFFFF0000);

        obj.webm = webm;
        obj.frameRate = webm.frameRate;
        obj.duration = webm.duration;
        obj.width = webm.width;
        obj.height = webm.height;

        webm.play();
        #end

        return obj;
    }

    function getWebm(id:Int, f:WebmDisplay->Void) {
        if (webms.exists(id)) {
            f(webms.get(id));
        }
    }

    public function new() {
        webms = new Map();

        #if (sys && !neko && !disableThread2)
        thread = ThreadSync.create({}, function(sendMessage, data, close) {
            // Initialization
            var webms:Map<Int, WebmProcess> = new Map();

            function getWebm(id:Int, f:WebmProcess->Void) {
                if (webms.exists(id)) {
                    f(webms.get(id));
                }
            }

            return { 
            fps: 24,//120, 
            received: function(type, data) {
                // Message Received from Thread
                return switch(type) {
                    case Create : 
                        var webm = new WebmPlayer(new WebmIoFile(data.path), false, true, function(bytes) {
                            sendMessage(Frame, {id: data.id, bytes: bytes});
                        });
                        webms.set(id, {webm: webm, id: data.id});
                        sendMessage(Info, { 
                            id: data.id, 
                            width: webm.width, 
                            height: webm.height, 
                            frameRate: webm.frameRate, 
                            duration: webm.duration 
                        });
                        webm.play();
                        false;
                    case Play : 
                        getWebm(data.id, function(webm) {
                            webm.webm.play();
                        });
                        false;
                    case Stop : 
                        getWebm(data.id, function(webm) {
                            webm.webm.stop();

                            // Also dispose
                            webm.webm.dispose();
                            webms.remove(data.id);
                        });
                        false;
                    default: 
                        false;
                }
                // -- Received
            }, processed: function() {
                webms.iter(function(webm) {
                    webm.webm.process();
                    sendMessage(FrameInfo, { id: webm.id, lastRequestedVideoFrame: webm.webm.lastRequestedVideoFrame });
                });
            }, disposed: function() {
                webms.iter(function(webm) {
                    webm.webm.stop();
                    webm.webm.dispose();
                });
                webms = new Map();
            }};
            // -- Initialization
        }, function(type:Int, data:Dynamic) {
            function getWebm(id:Int, f:WebmDisplay->Void) {
                if (webms.exists(id)) {
                    f(webms.get(id));
                }
            }
            
            // Message Sent from Thread
            switch(type) {
                case FrameInfo:
                    getWebm(data.id, function(webm) {
                        webm.lastRequestedVideoFrame = data.lastRequestedVideoFrame;
                    });
                case Info  : 
                    getWebm(data.id, function(webm) {
                        webm.frameRate = data.frameRate;
                        webm.duration = data.duration;
                        webm.width = data.width;
                        webm.height = data.height;

                        webm.bitmap.bitmapData = new BitmapData(data.width, data.height, true, 0x00000000);
                        webm.bitmap.smoothing = true;

                        if (webm.loaded != null) webm.loaded();
                    });
                case Frame : 
                    getWebm(data.id, function(webm) {
                        // Copy bytes
                        // TODO: Do it from the Thread instead??? (IS IT NECESSARY!?!?!?)
                        var bytes = haxe.io.Bytes.alloc(data.bytes.length);
                        bytes.blit(0, data.bytes, 0, data.bytes.length);

                        if (webm.bitmap.bitmapData != null) {
                            onFrame(webm, bytes);
                            //onFrame(webm.bitmap, cast data.bytes);
                        }
                    });
                case -1:
                    // TODO: Too agressive?
                    getWebm(data.id, function(webm) {
                        //if (webm.bitmap.bitmapData != null) webm.bitmap.bitmapData.dispose();
                    });
            }
            // -- Sent
        });
        #else
        openfl.Lib.current.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
        #end
    }

    function enterFrameHandler(e) {
        #if (sys && !neko && !disableThread2)
        
        #else
        webms.iter(function(webm) {
            webm.webm.process();
            webm.lastRequestedVideoFrame = webm.webm.lastRequestedVideoFrame;
        });
        #end
    }

    public function play(id:Int) {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Play, {id: id});
        #else
        getWebm(id, function(webm) {
            webm.webm.play();
        });
        #end
    }

    function onFrame(webm:WebmDisplay, bytes) {
        var byteArray:ByteArray = ByteArray.fromBytes(bytes);

        webm.bitmap.bitmapData.lock();
        webm.bitmap.bitmapData.setPixels(webm.bitmap.bitmapData.rect, byteArray);
        webm.bitmap.bitmapData.unlock();

        // TODO: Too aggressive?
        //byteArray.clear();

        webm.bitmap.smoothing = true;

        if (!webm.firstFrame) {
            webm.firstFrame = true;
            if (webm.loaded != null) {
                webm.loaded();
                webm.loaded = null;
            }
        }
    }

    public function stop(id:Int) {
        #if (sys && !neko && !disableThread2)
        thread.sendMessage(Stop, {id: id});
        #else
        getWebm(id, function(webm) {
            webm.webm.stop();
            webm.webm.dispose();

        });
        #end
        
        // TODO: Too aggressive?
        //if (bitmapData != null) bitmapData.dispose();
        //bitmapData = null;

        webms.remove(id);
    }

    public function dispose() {
        webms.iter(function(webm) {
            webm.webm.stop();
            webm.webm.dispose();

            // TODO: Too aggressive?
            //if (bitmapData != null) bitmapData.dispose();
            //bitmapData = null;
        });
        webms = new Map();

        openfl.Lib.current.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
    }
}
