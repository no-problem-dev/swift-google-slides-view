#!/usr/bin/env python3
import json, sys, re

disc = json.load(open(sys.argv[1]))
schemas = disc["schemas"]

# Types already implemented in the read model — reuse, never regenerate.
EXISTING = set("""AffineTransform Alignment Autofit AutofitType AutoText AutoTextType BaselineOffset Bullet
ColorScheme ColorStop ContentAlignment CropProperties DashStyle Dimension Group Image ImageProperties
LayoutProperties LayoutReference Line LineFill LineProperties Link List MasterProperties NestingLevel
NotesProperties OpaqueColor OptionalColor Outline OutlineFill Page PageBackgroundFill PageElement
PageProperties PageType ParagraphMarker ParagraphStyle Placeholder PlaceholderType PredefinedLayout
Presentation PropertyState Recolor RecolorName RectanglePosition RgbColor Shadow ShadowType Shape
ShapeBackgroundFill ShapeProperties ShapeType SheetsChart SheetsChartProperties Size SlideProperties
SolidFill SpeakerSpotlight SpeakerSpotlightProperties StretchedPictureFill Table TableCell
TableCellLocation TableRow TextContent TextElement TextRun TextStyle ThemeColorPair ThemeColorType
Unit Video VideoProperties WeightedFontFamily WordArt""".split())

# Roots: every *Request and *Response, plus the Request/Response wrappers.
roots = [n for n in schemas if n.endswith("Request") or n.endswith("Response")]

generated = {}       # name -> swift code
enums = {}           # name -> [values]
order = []

def swift_enum_name(schema, field):
    return schema + field[0].upper() + field[1:]

def field_type(schema_name, fname, prop):
    # returns (swift_type, also-queue-refs)
    if "$ref" in prop:
        ref = prop["$ref"]
        queue(ref)
        return ref
    t = prop.get("type")
    if t == "string":
        if "enum" in prop:
            ename = swift_enum_name(schema_name, fname)
            enums[ename] = prop["enum"]
            return ename
        return "String"
    if t == "integer": return "Int"
    if t == "number": return "Double"
    if t == "boolean": return "Bool"
    if t == "array":
        it = prop["items"]
        if "$ref" in it:
            queue(it["$ref"]); return f"[{it['$ref']}]"
        sub = {"string":"String","integer":"Int","number":"Double","boolean":"Bool"}.get(it.get("type"),"StructuredJSON")
        return f"[{sub}]"
    if t == "object":
        ap = prop.get("additionalProperties")
        if ap and "$ref" in ap:
            queue(ap["$ref"]); return f"[String: {ap['$ref']}]"
        if ap and ap.get("type"):
            sub = {"string":"String","integer":"Int","number":"Double","boolean":"Bool"}.get(ap["type"],"StructuredJSON")
            return f"[String: {sub}]"
        return "StructuredJSON"
    return "StructuredJSON"

_queue = []
def queue(name):
    if name not in EXISTING and name in schemas and name not in generated and name not in _queue:
        _queue.append(name)

for r in roots: queue(r)

def lower_first(s): return s[0].lower()+s[1:]

while _queue:
    name = _queue.pop(0)
    if name in generated: continue
    generated[name] = None  # mark
    props = schemas[name].get("properties", {})
    fields = []
    for fname, prop in props.items():
        st = field_type(name, fname, prop)
        fields.append((fname, st))
    # emit struct
    lines = [f"public struct {name}: Codable, Equatable, Sendable {{"]
    for fname, st in fields:
        lines.append(f"    public var {fname}: {st}?")
    if fields:
        args = ",\n".join(f"        {f}: {t}? = nil" for f,t in fields)
        lines.append("")
        lines.append("    public init(")
        lines.append(args)
        lines.append("    ) {")
        for f,_ in fields:
            lines.append(f"        self.{f} = {f}")
        lines.append("    }")
    else:
        lines.append("    public init() {}")
    lines.append("}")
    generated[name] = "\n".join(lines)
    order.append(name)

# Fully-typed invariant: the write model must describe every field concretely — never an `any`-style
# escape hatch. If discovery ever introduces a genuinely free-form field, fail loudly so we model it
# by hand instead of silently degrading to a dynamic value.
offenders = [n for n in order if "StructuredJSON" in generated[n]]
if offenders:
    sys.stderr.write("ERROR: free-form (StructuredJSON) fields would be emitted — model these concretely: "
                     + ", ".join(offenders) + "\n")
    sys.exit(1)

# Emit enums
enum_code = []
for ename in sorted(enums):
    vals = enums[ename]
    cases = []
    for v in vals:
        cn = re.sub(r'_([a-z])', lambda m: m.group(1).upper(), v.lower())
        cn = re.sub(r'[^A-Za-z0-9]', '', cn)
        if cn and cn[0].isdigit(): cn = "_"+cn
        if cn in ("default","case","switch","public","static"): cn = cn+"_"
        cases.append((cn, v))
    lines = [f"public struct {ename}: SpecEnum {{",
             "    public var rawValue: String",
             "    public init(rawValue: String) { self.rawValue = rawValue }",
             ""]
    for cn, v in cases:
        lines.append(f'    public static let {cn} = Self(rawValue: "{v}")')
    lines.append("")
    lines.append("    public static var knownValues: [Self] { [" + ", ".join("."+cn for cn,_ in cases) + "] }")
    lines.append("}")
    enum_code.append("\n".join(lines))

print("// Generated from the Google Slides API discovery document (batchUpdate write model).")
print("// Field-faithful Codable mirror; all properties optional for resilient decoding.")
print("import GSlidesSchema\n")
print("\n\n".join(enum_code))
print()
print("\n\n".join(generated[n] for n in order))

# Typed union over the `Request` oneof — generated from the discovery `Request` schema so the case
# set can never drift from the wire protocol. Every member field gets a Kind case + a factory.
req_kinds = [(f, p["$ref"]) for f, p in schemas["Request"]["properties"].items() if "$ref" in p]
union = []
union.append("")
union.append("/// Typed accessor over the `Request` oneof — mirrors `PageElement.Kind`: exactly one member is")
union.append("/// set. Generated from the discovery `Request` schema, so its case set EQUALS the wire protocol")
union.append("/// (a parity test pins it). Unknown/empty requests map to `.other` and still round-trip via the")
union.append("/// stored optional fields.")
union.append("extension Request {")
union.append("    public enum Kind: Equatable, Sendable {")
for f, t in req_kinds:
    union.append(f"        case {f}({t})")
union.append("        /// No member set (an empty request), or a kind newer than this generated mirror.")
union.append("        case other")
union.append("    }")
union.append("")
union.append("    /// The first set member as a typed case.")
union.append("    public var kind: Kind {")
for f, _ in req_kinds:
    union.append(f"        if let r = {f} {{ return .{f}(r) }}")
union.append("        return .other")
union.append("    }")
union.append("")
for f, t in req_kinds:
    union.append(f"    public static func {f}(_ r: {t}) -> Request {{ Request({f}: r) }}")
union.append("}")
print("\n".join(union))

sys.stderr.write(f"generated {len(order)} structs, {len(enums)} enums, {len(req_kinds)} request kinds\n")
sys.stderr.write("structs: " + " ".join(order) + "\n")
