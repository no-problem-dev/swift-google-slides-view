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
    lines = [f"public struct {name}: Codable, Hashable, Sendable {{"]
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
print("import GSlidesSchema\nimport StructuredDataCore\n")
print("/// Escape hatch for free-form JSON values in a few request fields.")
print("public typealias StructuredJSON = StructuredValue\n")
print("\n\n".join(enum_code))
print()
print("\n\n".join(generated[n] for n in order))
sys.stderr.write(f"generated {len(order)} structs, {len(enums)} enums\n")
sys.stderr.write("structs: " + " ".join(order) + "\n")
