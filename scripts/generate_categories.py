#!/usr/bin/env python3
"""
Script to parse https://www.bg-wiki.com/ffxi/Category:Trust and generate trustCategories.lua
Extracts trust names organized by their categories.
"""

import re
from html.parser import HTMLParser
from pathlib import Path
import urllib.request
import urllib.error

WIKI_URL = "https://www.bg-wiki.com/ffxi/Category:Trust"

class TrustCategoryParser(HTMLParser):
    """Parser to extract trust names from category sections in HTML."""
    
    def __init__(self):
        super().__init__()
        self.categories = {
            'Tank': [],
            'Melee Fighter': [],
            'Ranged Fighter': [],
            'Offensive Caster': [],
            'Healer': [],
            'Support': [],
            'Special': [],
            'Unity Concord': []
        }
        self.current_category = None
        self.in_category_row = False
        self.in_trust_links_cell = False
        self.in_link = False
        self.current_link_text = []
        self.row_count = 0
        
    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        
        # Track table rows
        if tag == 'tr':
            self.row_count += 1
        
        # Check if we're in a table cell with category header
        if tag == 'td':
            # Check for category header (has background color and contains category name)
            if 'style' in attrs_dict and 'background: rgb(166, 219, 253)' in attrs_dict['style']:
                self.in_category_row = True
                self.in_trust_links_cell = False
            # If previous cell was category header, this cell has the trust links
            elif self.current_category and not self.in_trust_links_cell:
                self.in_trust_links_cell = True
        
        # Check for links to trusts
        if tag == 'a':
            href = attrs_dict.get('href', '')
            # Links to individual trusts contain BGWiki:Trusts#
            if 'BGWiki:Trusts#' in href and self.in_trust_links_cell:
                self.in_link = True
                self.current_link_text = []
    
    def handle_endtag(self, tag):
        if tag == 'tr':
            self.in_category_row = False
            self.in_trust_links_cell = False
        
        if tag == 'td':
            if self.in_trust_links_cell:
                # Keep the cell open for multiple links
                pass
        
        if tag == 'a' and self.in_link:
            # Save the trust name to the current category
            if self.current_link_text and self.current_category:
                trust_name = ''.join(self.current_link_text).strip()
                if trust_name and trust_name not in ['Tanks', 'Melee Fighter', 'Ranged Fighter', 
                                                       'Offensive Caster', 'Healer', 'Support', 
                                                       'Special', 'Unity Concord']:
                    if trust_name not in self.categories[self.current_category]:
                        self.categories[self.current_category].append(trust_name)
            self.in_link = False
            self.current_link_text = []
    
    def handle_data(self, data):
        data = data.strip()
        
        # Check if this is a category header
        if self.in_category_row and data and not self.in_link:
            # Remove "Tanks" -> "Tank", keep others as-is
            if data == 'Tanks':
                self.current_category = 'Tank'
            elif data in self.categories:
                self.current_category = data
        
        # Collect link text
        if self.in_link:
            self.current_link_text.append(data)


def parse_html_content(html_content):
    """Parse the HTML content and extract trust categories using regex."""
    # Use regex since live HTML structure differs from saved file
    categories = {
        'Tank': [],
        'Melee Fighter': [],
        'Ranged Fighter': [],
        'Offensive Caster': [],
        'Healer': [],
        'Support': [],
        'Special': [],
        'Unity Concord': []
    }
    
    # Category name mapping
    category_map = {
        'Tanks': 'Tank',
        'Melee Fighter': 'Melee Fighter',
        'Ranged Fighter': 'Ranged Fighter',
        'Offensive Caster': 'Offensive Caster',
        'Healer': 'Healer',
        'Support': 'Support',
        'Special': 'Special',
        'Unity Concord': 'Unity Concord'
    }
    
    # Find sections by <big> tags containing category names
    for wiki_name, category in category_map.items():
        # Pattern to find category section and extract trusts
        # Look for <big>CategoryName</big> then find all trust links until next <big>
        pattern = rf'<big>\s*{re.escape(wiki_name)}\s*</big>(.*?)(?=<big>|$)'
        match = re.search(pattern, html_content, re.DOTALL)
        
        if match:
            section = match.group(1)
            # Extract trust names from links
            trust_pattern = r'<a[^>]+href="[^"]*"[^>]*>([^<]+)</a>'
            
            for trust_match in re.finditer(trust_pattern, section):
                trust_name = trust_match.group(1).strip()
                
                # Skip category headers and navigation
                if trust_name in ['Tanks', 'Melee Fighter', 'Ranged Fighter', 
                                 'Offensive Caster', 'Healer', 'Support', 
                                 'Special', 'Unity Concord', 'Trust', 'Category:Trust',
                                 'Category', 'Main Page', 'Random page', 'Help', 'Edit']:
                    continue
                
                # Skip empty or very short names
                if len(trust_name) < 2:
                    continue
                
                if trust_name and trust_name not in categories[category]:
                    categories[category].append(trust_name)
    
    return categories


def generate_lua_file(categories, output_path):
    """Generate the Lua file with trust categories."""
    
    # Get current date
    from datetime import datetime
    current_date = datetime.now().strftime('%Y-%m-%d')
    
    # Start building the Lua content
    lua_content = ['-- Auto-generated trust categories from FFXI Wiki',
                   f'-- Source: {WIKI_URL}',
                   f'-- Generated: {current_date}',
                   '',
                   'local trustCategories = {']
    
    # Add each category
    for category, trusts in categories.items():
        lua_content.append(f'    ["{category}"] = {{')
        
        for trust in trusts:
            # Escape quotes in trust names
            escaped_name = trust.replace('"', '\\"')
            lua_content.append(f'        "{escaped_name}",')
        
        lua_content.append('    },')
    
    lua_content.append('}')
    lua_content.append('')
    lua_content.append('return trustCategories')
    
    # Write to file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lua_content))
    
    print(f"Generated {output_path}")
    
    # Print summary
    print("\nCategory summary:")
    for category, trusts in categories.items():
        print(f"  {category}: {len(trusts)} trusts")
    print(f"  Total trusts: {sum(len(trusts) for trusts in categories.values())}")


def main():
    """Main function."""
    # Get script directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # URL and output path
    wiki_url = WIKI_URL
    output_file = project_root / "data" / "trustCategories.lua"
    
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
    categories = parse_html_content(html_content)
    
    # Generate Lua file
    print(f"Generating {output_file}...")
    generate_lua_file(categories, output_file)
    
    print("Done!")
    return 0


if __name__ == '__main__':
    exit(main())
