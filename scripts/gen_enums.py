#!/usr/bin/env python3
"""Generate complete SpecEnum bodies from the pinned Slides API discovery document.

Each SpecEnum mirrors a discovery enum (schema.property). This emits the full set of named
constants + knownValues so the model is a complete mirror (enforced by EnumParityTests == discovery).

Usage: python3 scripts/gen_enums.py            # prints Swift for all registered enums
       python3 scripts/gen_enums.py ShapeType  # prints one
"""
import json, os, sys

DISCOVERY = os.path.join(os.path.dirname(__file__), "..", "..", "references", "slides-api-discovery-v1.json")

# SwiftTypeName -> (schema, property). Mirrors EnumParityTests.registry.
REGISTRY = {
    "ShapeType": ("Shape", "shapeType"),
    "RecolorName": ("Recolor", "name"),
    "LineType": ("Line", "lineType"),
    "LineCategory": ("Line", "lineCategory"),
}

SWIFT_KEYWORDS = {"default", "internal", "public", "static", "repeat", "case", "where", "operator", "in", "is", "as"}


def swift_name(value: str) -> str:
    """SCREAMING_SNAKE -> lowerCamelCase, with the discovery sentinels shortened to match the
    existing hand-written naming (FOO_UNSPECIFIED -> unspecified, FOO_UNSUPPORTED -> unsupported)."""
    if value.endswith("UNSPECIFIED"):
        return "unspecified"
    if value.endswith("UNSUPPORTED"):
        return "unsupported"
    parts = value.split("_")
    name = parts[0].lower() + "".join(p.capitalize() for p in parts[1:])
    return f"`{name}`" if name in SWIFT_KEYWORDS else name


def emit(type_name: str, schema: str, prop: str, schemas: dict) -> str:
    values = schemas[schema]["properties"][prop]["enum"]
    lines = [f"public struct {type_name}: SpecEnum {{",
             "    public var rawValue: String",
             "    public init(rawValue: String) { self.rawValue = rawValue }",
             ""]
    for v in values:
        lines.append(f'    public static let {swift_name(v)} = Self(rawValue: "{v}")')
    lines.append("")
    lines.append("    public static var knownValues: [Self] {")
    names = ", ".join("." + swift_name(v) for v in values)
    lines.append(f"        [{names}]")
    lines.append("    }")
    lines.append("}")
    return "\n".join(lines)


def main():
    schemas = json.load(open(DISCOVERY))["schemas"]
    targets = sys.argv[1:] or list(REGISTRY)
    blocks = []
    for t in targets:
        schema, prop = REGISTRY[t]
        blocks.append(emit(t, schema, prop, schemas))
    print("\n\n".join(blocks))


if __name__ == "__main__":
    main()
