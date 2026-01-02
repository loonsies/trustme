#!/usr/bin/env python3
"""
Script to parse https://www.bg-wiki.com/ffxi/Category:Trust and generate trustInformation.json
Extracts comprehensive data for each trust including job, spells, abilities, weapon skills, etc.
"""

import re
import json
import html
from html.parser import HTMLParser
from pathlib import Path
from datetime import datetime
import urllib.request
import urllib.error

WIKI_URL = "https://www.bg-wiki.com/ffxi/Category:Trust"


def parse_html_file(html_path):
    """Parse the HTML file using regex to extract trust information."""
    
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    return parse_html_content_from_string(content)


def parse_html_content_from_string(content):
    """Parse HTML content string using regex to extract trust information."""
    trusts = {}
    
    # Find all trust tables - they are in divs with class "two-column-flex-item"
    # Each table starts with a trust name header
    
    # Pattern to find trust name headers
    name_pattern = r'<big>([^<]+)</big>'
    
    # Split content by wikitable to process each trust table
    tables = re.split(r'<table class="wikitable"', content)
    
    for table in tables[1:]:  # Skip first split (before any table)
        # Try to find trust name
        name_match = re.search(name_pattern, table)
        if not name_match:
            continue
            
        trust_name = name_match.group(1).strip()
        
        # Skip if already processed or not a valid trust name
        if trust_name in trusts or trust_name in ['', 'Tanks', 'Melee Fighter', 'Ranged Fighter', 
                                                   'Offensive Caster', 'Healer', 'Support', 
                                                   'Special', 'Unity Concord']:
            continue
        
        # Initialize trust data
        trust_data = {
            'name': trust_name,
            'job': extract_field(table, 'Job'),
            'spells': extract_field(table, 'Spells'),
            'abilities': extract_field(table, 'Abilities'),
            'weapon_skills': extract_field(table, 'Weapon Skills'),
            'acquisition': extract_section(table, 'Acquisition'),
            'special_features': extract_section(table, 'Special Features')
        }
        
        trusts[trust_name] = trust_data
    
    return trusts


def extract_field(table_html, field_name):
    """Extract a field value (Job, Spells, Abilities, Weapon Skills) from table HTML."""
    # Pattern: <td>field_name</td> followed by <td>content</td>
    pattern = rf'<td[^>]*>\s*{re.escape(field_name)}\s*</td>\s*<td[^>]*>(.*?)</td>'
    match = re.search(pattern, table_html, re.DOTALL | re.IGNORECASE)
    
    if not match:
        return None
    
    content = match.group(1)
    
    # Parse links and text from the content
    result = parse_html_content(content)
    
    return result if result else None


def extract_section(table_html, section_name):
    """Extract a section (Acquisition, Special Features) from table HTML."""
    # Find section header
    section_pattern = rf'<span[^>]*>{re.escape(section_name)}</span>'
    section_match = re.search(section_pattern, table_html, re.IGNORECASE)
    
    if not section_match:
        return None
    
    # Find the content after the section header (in the next <td colspan="3">)
    # Look for content between section header row and next section header or end of table
    start_pos = section_match.end()
    
    # Find the next <td colspan="3"> which contains the section content
    content_pattern = r'<td colspan="3"[^>]*>(.*?)(?:<td colspan="3"|</table>)'
    content_match = re.search(content_pattern, table_html[start_pos:], re.DOTALL)
    
    if not content_match:
        return None
    
    content = content_match.group(1)
    
    # Parse the content
    result = parse_html_content(content)
    
    return result if result else None


def parse_html_content(html_content):
    """Parse HTML content and extract text with links, organized by lines."""
    if not html_content or html_content.strip() == 'None':
        return None
    
    # Split by <li> tags for bullet points, or <br> for line breaks
    lines_raw = re.split(r'<li[^>]*>|<br\s*/?>', html_content)
    
    result = []
    
    for line_html in lines_raw:
        if not line_html or not line_html.strip():
            continue
        
        # Clean up closing tags
        line_html = re.sub(r'</li>', '', line_html)
        line_html = re.sub(r'</?p[^>]*>', '', line_html)
        
        line_items = []
        
        # First pass: extract all elements with their positions
        elements = []
        
        # Extract links with positions
        link_pattern = r'<a\s+[^>]*href="([^"]*)"[^>]*>([^<]*)</a>'
        for match in re.finditer(link_pattern, line_html):
            url = match.group(1)
            # Convert relative URLs to absolute URLs
            if url.startswith('/'):
                url = 'https://www.bg-wiki.com' + url
            elif not url.startswith('http'):
                url = 'https://www.bg-wiki.com/ffxi/' + url
            elements.append({
                'pos': match.start(),
                'end': match.end(),
                'type': 'link',
                'text': match.group(2).strip(),
                'url': url
            })
        
        # Extract skillchain icons with positions
        sc_pattern = r'<img[^>]*alt="([^"]*SC Icon[^"]*)"[^>]*>'
        for match in re.finditer(sc_pattern, line_html):
            sc_name = match.group(1).replace(' SC Icon.png', '').replace(' SC Icon', '')
            if sc_name:
                elements.append({
                    'pos': match.start(),
                    'end': match.end(),
                    'type': 'skillchain',
                    'value': sc_name
                })
        
        # Extract Status_Ability icon (used for "none" skillchain indicator)
        # Match various possible patterns for the status ability icon
        status_patterns = [
            r'<img[^>]*alt="None"[^>]*src="[^"]*Status_Ability\.png"[^>]*>',
            r'<img[^>]*src="[^"]*Status_Ability\.png"[^>]*alt="None"[^>]*>'
        ]
        for pattern in status_patterns:
            for match in re.finditer(pattern, line_html, re.IGNORECASE):
                elements.append({
                    'pos': match.start(),
                    'end': match.end(),
                    'type': 'skillchain',
                    'value': 'Status_Ability'
                })
        
        # Sort elements by position
        elements.sort(key=lambda x: x['pos'])
        
        # Build line_items by interleaving text and elements in order
        pos = 0
        for elem in elements:
            # Add text before this element
            text_before = line_html[pos:elem['pos']]
            text_before = re.sub(r'<[^>]+>', '', text_before)  # Remove other tags
            text_before = html.unescape(text_before)  # Decode HTML entities
            text_before = re.sub(r'\s+', ' ', text_before)  # Normalize whitespace to single spaces
            text_before = text_before.strip()
            # If text is just "/" with optional spaces, preserve as " / "
            if re.match(r'^\s*/\s*$', text_before):
                text_before = ' / '
            if text_before:
                line_items.append({'type': 'text', 'value': text_before})
            
            # Add the element itself
            if elem['type'] == 'link':
                if elem['text']:
                    line_items.append({
                        'type': 'link',
                        'text': elem['text'],
                        'url': elem['url']
                    })
            elif elem['type'] == 'skillchain':
                line_items.append({
                    'type': 'skillchain',
                    'value': elem['value']
                })
            
            pos = elem['end']
        
        # Add remaining text after all elements
        text_after = line_html[pos:]
        text_after = re.sub(r'<[^>]+>', '', text_after)  # Remove all HTML tags
        text_after = html.unescape(text_after)  # Decode HTML entities
        text_after = re.sub(r'\s+', ' ', text_after)  # Normalize whitespace to single spaces
        text_after = text_after.strip()
        # If text is just "/" with optional spaces, preserve as " / "
        if re.match(r'^\s*/\s*$', text_after):
            text_after = ' / '
        if text_after:
            line_items.append({'type': 'text', 'value': text_after})
        
        # Merge trailing punctuation into preceding elements
        i = 0
        while i < len(line_items):
            item = line_items[i]
            if item['type'] == 'text' and item['value'] in ['.', ',', ':', ';', '!', '?']:
                # Attach punctuation to previous item (but NOT to skillchains, they need exact names for icon lookup)
                if i > 0:
                    prev = line_items[i - 1]
                    if prev['type'] == 'link':
                        prev['text'] += item['value']
                        line_items.pop(i)
                        continue
                    elif prev['type'] == 'text':
                        prev['value'] += item['value']
                        line_items.pop(i)
                        continue
                    # Don't attach to skillchains - leave punctuation as separate text
            elif item['type'] == 'text':
                # Check if text starts with punctuation
                value = item['value']
                if value and value[0] in ['.', ',', ':', ';', '!', '?']:
                    if i > 0:
                        prev = line_items[i - 1]
                        if prev['type'] == 'link':
                            prev['text'] += value[0]
                            # Remove punctuation from current text
                            item['value'] = value[1:].lstrip()
                            if not item['value']:
                                line_items.pop(i)
                                continue
                        elif prev['type'] == 'text':
                            prev['value'] += value[0]
                            # Remove punctuation from current text
                            item['value'] = value[1:].lstrip()
                            if not item['value']:
                                line_items.pop(i)
                                continue
                        # Don't attach to skillchains
            i += 1
        
        if line_items:
            result.append(line_items)
    
    return result if result else None


def generate_json_file(trusts, output_path):
    """Generate the JSON file with trust information."""
    
    # Create output structure
    output = {
        'metadata': {
            'source': WIKI_URL,
            'generated': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'trust_count': len(trusts)
        },
        'trusts': trusts
    }
    
    # Write to file with pretty formatting
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"Generated {output_path}")
    print(f"Total trusts parsed: {len(trusts)}")


def main():
    """Main function."""
    # Get script directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # URL and output paths
    wiki_url = WIKI_URL
    output_file = project_root / "data" / "trustInformation.json"
    
    # Download HTML from URL
    print(f"Downloading HTML from {wiki_url}...")
    try:
        with urllib.request.urlopen(wiki_url) as response:
            html_content = response.read().decode('utf-8')
    except urllib.error.URLError as e:
        print(f"Error downloading HTML: {e}")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    print(f"Parsing HTML content...")
    trusts = parse_html_content_from_string(html_content)
    
    # Generate JSON file
    print(f"Generating {output_file}...")
    generate_json_file(trusts, output_file)
    
    print("Done!")
    return 0


if __name__ == '__main__':
    exit(main())
