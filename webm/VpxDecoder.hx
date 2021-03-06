package webm;

import cpp.Lib;
import haxe.io.Bytes;
import haxe.io.BytesData;

class VpxDecoder
{	
	public static var version(get, null):String;
	static function get_version():String
	{
		return hx_vpx_codec_iface_name();
	}

    public var frameHandler:Bytes->Void = null;
	
	private var context:Dynamic;
	
	public function new() 
	{
		context = hx_vpx_codec_dec_init();
	}
	
    public function destroy() {
        hx_vpx_codec_destroy(context);
    }

	public function decode(data:BytesData, alphaData:BytesData)
	{
		hx_vpx_codec_decode(context, data, alphaData);
	}
	
	public function getAndRenderFrame()
	{
		var info = hx_vpx_codec_get_frame(context);
		
		if (info != null) 
		{
			//var buffer = bitmapData.image.buffer;
			//buffer.data.buffer = Bytes.ofData(info[2]);
			//buffer.format = ARGB32;
			//buffer.premultiplied = true;
			//bitmapData.image.format = BGRA32;
			//bitmapData.image.version++;

            if (frameHandler != null) {
                frameHandler(Bytes.ofData(info[2]));
            }
		}
	}
	
	static var hx_vpx_codec_iface_name:Void -> String = Lib.load("extension-webm", "hx_vpx_codec_iface_name", 0);
	static var hx_vpx_codec_dec_init:Void -> Dynamic = Lib.load("extension-webm", "hx_vpx_codec_dec_init", 0);
	static var hx_vpx_codec_decode:Dynamic -> BytesData -> BytesData -> Array<Int> = Lib.load("extension-webm", "hx_vpx_codec_decode", 3);
	static var hx_vpx_codec_get_frame:Dynamic -> Array<Dynamic> = Lib.load("extension-webm", "hx_vpx_codec_get_frame", 1);
    static var hx_vpx_codec_destroy:Dynamic -> Dynamic = Lib.load("extension-webm", "hx_vpx_codec_destroy", 1);
}