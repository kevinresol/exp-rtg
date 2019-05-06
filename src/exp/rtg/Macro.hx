package exp.rtg;

import haxe.macro.Expr;
import haxe.macro.Context;
import tink.macro.BuildCache;
using tink.MacroApi;

class Macro {
	public static function buildStringTransport(base:Expr) {
		return BuildCache.getType2(Context.getLocalType().getID(), (ctx:BuildContext2) -> {
			var name = ctx.name;
			var base = base.toString().asTypePath();
			var command = ctx.type.toComplex();
			var message = ctx.type2.toComplex();
			var uplink = macro:exp.rtg.Transport.UplinkEnvelope<$command>;
			var downlink = macro:exp.rtg.Transport.DownlinkEnvelope<$message>;
			
			var def = macro class $name extends $base<$command, $message> {
				override function stringifyUplink(envelope:$uplink):String return tink.Json.stringify(envelope);
				override function stringifyDownlink(envelope:$downlink):String return tink.Json.stringify(envelope);
				override function parseUplink(s:String) return tink.Json.parse((s:$uplink));
				override function parseDownlink(s:String) return tink.Json.parse((s:$downlink));
			}
			
			def.pack = ['exp', 'rtg', 'transport'];
			return def;
		});
	}
}