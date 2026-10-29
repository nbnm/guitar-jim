"""Read the supplied DOCX as source material and preserve its content in Markdown.

Usage: python3 Scripts/convert_prd.py /path/to/Acoustic_Guitar_Practice_PRD.docx
Uses only Python's standard library; never executes document content.
"""
from pathlib import Path
from zipfile import ZipFile
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'

def convert(source):
    with ZipFile(source) as archive:
        relationships = {
            item.attrib['Id']: item.attrib['Target']
            for item in ET.fromstring(archive.read('word/_rels/document.xml.rels'))
        }
        body = ET.fromstring(archive.read('word/document.xml')).find(W + 'body')
        lines = []
        for item in body:
            if item.tag == W + 'p':
                parts = []
                for child in item:
                    value = ''.join(t.text or '' for t in child.iter(W + 't'))
                    if child.tag == W + 'hyperlink' and child.get(R + 'id') in relationships:
                        value = f'[{value}]({relationships[child.get(R + "id")]})'
                    parts.append(value)
                value = ''.join(parts).strip()
                style = item.find('./' + W + 'pPr/' + W + 'pStyle')
                style_name = style.get(W + 'val', '') if style is not None else ''
                prefix = {'Title': '# ', 'Heading1': '## ', 'Heading2': '### ', 'Heading3': '#### '}.get(style_name, '')
                if value.startswith('• '):
                    value = '- ' + value[2:]
                if value:
                    lines.extend([prefix + value, ''])
                if item.find('.//' + W + 'drawing') is not None:
                    lines.extend(['![Illustrative practice layout from the PRD](assets/practice-layout.png)', ''])
            elif item.tag == W + 'tbl':
                rows = []
                for row in item.findall(W + 'tr'):
                    cells = [' '.join(t.text or '' for t in c.iter(W + 't')).replace('|', '\\|') for c in row.findall(W + 'tc')]
                    rows.append('| ' + ' | '.join(cells) + ' |')
                if rows:
                    lines.extend([rows[0], '| ' + ' | '.join('---' for _ in item.findall(W + 'tr')[0].findall(W + 'tc')) + ' |', *rows[1:], ''])
        (ROOT / 'docs/assets').mkdir(parents=True, exist_ok=True)
        (ROOT / 'docs/assets/practice-layout.png').write_bytes(archive.read('word/media/image1.png'))
        note = ('> Converted from `Acoustic_Guitar_Practice_PRD.docx`, version 0.1, 28 October 2026. '
                'The source requirements below are preserved as product input. The user subsequently selected '
                '**Light Element** for model access; see [implementation status](IMPLEMENTATION.md) for that integration and current delivery scope.\n\n')
        (ROOT / 'docs/Acoustic_Guitar_Practice_PRD.md').write_text(note + '\n'.join(lines), encoding='utf-8')

if __name__ == '__main__':
    convert(sys.argv[1])
