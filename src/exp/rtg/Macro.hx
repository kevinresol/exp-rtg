package exp.rtg;

import haxe.macro.Expr;
import haxe.macro.Context;
import tink.macro.BuildCache;
using tink.MacroApi;

class Macro {
	public static function buildStringTransport(base:Expr) {
		return BuildCache.getType2(Context.getLocalType().getID(), (ctx:BuildContext2) -> {
			var name = ctx.name;
			var command = ctx.type.toComplex();
			var message = ctx.type2.toComplex();
			var base = base.toString().asTypePath([TPType(command), TPType(message)]);
			var meta = getMetaType(base);
			var upmeta = meta.uplink;
			var downmeta = meta.downlink;
			var uplink = macro:exp.rtg.Transport.UplinkEnvelope<$upmeta, $command>;
			var downlink = macro:exp.rtg.Transport.DownlinkEnvelope<$downmeta, $message>;
			
			var def = macro class $name extends $base {
				override function stringifyUplink(envelope:$uplink):String return tink.Json.stringify(envelope);
				override function stringifyDownlink(envelope:$downlink):String return tink.Json.stringify(envelope);
				override function parseUplink(s:String) return tink.Json.parse((s:$uplink));
				override function parseDownlink(s:String) return tink.Json.parse((s:$downlink));
			}
			
			def.pack = ['exp', 'rtg', 'transport'];
			return def;
		});
	}
	
	static function getMetaType(base:TypePath) {
		switch TPath(base).toType() {
			case Success(TInst(_.get() => {superClass: parent}, _)):
				return {
					uplink: parent.params[0].toComplex(),
					downlink: parent.params[1].toComplex(),
				}
			case v:
				throw 'asserts';
		}
	}
}