package plan

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"unicode"
)

type VDF map[string]any

type vdfParser struct {
	text string
	pos  int
}

func ParseVDF(input string) (VDF, error) {
	p := &vdfParser{text: input}
	p.skipSpace()
	if p.consume('{') {
		value, err := p.object()
		if err != nil {
			return nil, err
		}
		p.skipSpace()
		if p.pos != len(p.text) {
			return nil, fmt.Errorf("trailing VDF data")
		}
		return VDF(value), nil
	}
	result := make(map[string]any)
	for {
		p.skipSpace()
		if p.pos >= len(p.text) {
			break
		}
		key, err := p.token()
		if err != nil {
			return nil, err
		}
		p.skipSpace()
		if !p.consume('{') {
			return nil, fmt.Errorf("VDF root value must be an object")
		}
		value, err := p.object()
		if err != nil {
			return nil, err
		}
		result[normalizeVDFKey(key)] = value
	}
	if len(result) == 0 {
		return nil, fmt.Errorf("VDF root is empty")
	}
	return VDF(result), nil
}

func (p *vdfParser) object() (map[string]any, error) {
	result := make(map[string]any)
	for {
		p.skipSpace()
		if p.consume('}') {
			return result, nil
		}
		if p.pos >= len(p.text) {
			return nil, fmt.Errorf("unterminated VDF object")
		}
		key, err := p.token()
		if err != nil {
			return nil, err
		}
		p.skipSpace()
		if p.consume('{') {
			value, err := p.object()
			if err != nil {
				return nil, err
			}
			result[normalizeVDFKey(key)] = value
			continue
		}
		value, err := p.token()
		if err != nil {
			return nil, err
		}
		result[normalizeVDFKey(key)] = value
	}
}

func (p *vdfParser) token() (string, error) {
	p.skipSpace()
	if p.pos >= len(p.text) {
		return "", fmt.Errorf("unexpected end of VDF")
	}
	if p.text[p.pos] == '"' {
		p.pos++
		var b strings.Builder
		for p.pos < len(p.text) {
			c := p.text[p.pos]
			p.pos++
			if c == '"' {
				return b.String(), nil
			}
			if c == '\\' && p.pos < len(p.text) {
				next := p.text[p.pos]
				p.pos++
				switch next {
				case 'n':
					b.WriteByte('\n')
				case 't':
					b.WriteByte('\t')
				default:
					b.WriteByte(next)
				}
				continue
			}
			b.WriteByte(c)
		}
		return "", fmt.Errorf("unterminated VDF string")
	}
	start := p.pos
	for p.pos < len(p.text) {
		c := rune(p.text[p.pos])
		if unicode.IsSpace(c) || c == '{' || c == '}' {
			break
		}
		p.pos++
	}
	if start == p.pos {
		return "", fmt.Errorf("empty VDF token")
	}
	return p.text[start:p.pos], nil
}

func (p *vdfParser) skipSpace() {
	for p.pos < len(p.text) {
		c := p.text[p.pos]
		if c == '/' && p.pos+1 < len(p.text) && p.text[p.pos+1] == '/' {
			p.pos += 2
			for p.pos < len(p.text) && p.text[p.pos] != '\n' {
				p.pos++
			}
			continue
		}
		if unicode.IsSpace(rune(c)) {
			p.pos++
			continue
		}
		break
	}
}

func (p *vdfParser) consume(c byte) bool {
	if p.pos < len(p.text) && p.text[p.pos] == c {
		p.pos++
		return true
	}
	return false
}

func normalizeVDFKey(value string) string {
	return strings.ToLower(value)
}

func MapValue(source VDF, key string) VDF {
	value, _ := source[strings.ToLower(key)].(map[string]any)
	return VDF(value)
}

func StringValue(source VDF, key string) string {
	value := source[strings.ToLower(key)]
	return fmt.Sprint(value)
}

func IntValue(source VDF, key string) int64 {
	value, _ := strconv.ParseInt(StringValue(source, key), 10, 64)
	return value
}

func StringifyVDF(root VDF) string {
	var builder strings.Builder
	builder.WriteString("\"")
	keys := make([]string, 0, len(root))
	for key := range root {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	// The caller normally supplies one AppState root. Preserve a valid root
	// pair when multiple top-level keys exist.
	if len(keys) == 1 {
		key := keys[0]
		builder.WriteString(escapeVDF(key))
		builder.WriteString("\"\n{\n")
		writeVDFObject(&builder, root[key], 1)
		builder.WriteString("}\n")
		return builder.String()
	}
	builder.WriteString("root\"\n{\n")
	writeVDFObject(&builder, root, 1)
	builder.WriteString("}\n")
	return builder.String()
}

func writeVDFObject(builder *strings.Builder, value any, depth int) {
	object, ok := value.(map[string]any)
	if !ok {
		return
	}
	keys := make([]string, 0, len(object))
	for key := range object {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	indent := strings.Repeat("\t", depth)
	for _, key := range keys {
		entry := object[key]
		if nested, ok := entry.(map[string]any); ok {
			builder.WriteString(indent)
			builder.WriteString("\"")
			builder.WriteString(escapeVDF(key))
			builder.WriteString("\"\n")
			builder.WriteString(indent)
			builder.WriteString("{\n")
			writeVDFObject(builder, nested, depth+1)
			builder.WriteString(indent)
			builder.WriteString("}\n")
			continue
		}
		builder.WriteString(indent)
		builder.WriteString("\"")
		builder.WriteString(escapeVDF(key))
		builder.WriteString("\"\t\t\"")
		builder.WriteString(escapeVDF(fmt.Sprint(entry)))
		builder.WriteString("\"\n")
	}
}

func escapeVDF(value string) string {
	return strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(value)
}
