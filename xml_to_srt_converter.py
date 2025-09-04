import os
import re
import xml.etree.ElementTree as ET

def clean_text(text):
    """Remove special characters from the text."""
    return re.sub(r'&#8230;', '', text)

def convert_xml_to_srt(xml_content):
    """Convert XML content to SRT format."""
    root = ET.fromstring(xml_content)
    srt_output = []
    index = 1

    for speaker in root.findall('.//speaker'):
        speaker_name = speaker.get('name')
        for utterance in speaker.findall('utterance'):
            text = clean_text(utterance.text)
            srt_output.append(f"{index}\n{speaker_name}: {text}\n")
            index += 1

    return ''.join(srt_output)

def process_file(file_path):
    """Process individual XML file and convert to SRT."""
    with open(file_path, 'r', encoding='utf-8') as xml_file:
        xml_content = xml_file.read()
    srt_content = convert_xml_to_srt(xml_content)
    srt_file_path = f"{os.path.splitext(file_path)[0]}.srt"
    with open(srt_file_path, 'w', encoding='utf-8') as srt_file:
        srt_file.write(srt_content)
    print(f"Converted {file_path} to {srt_file_path}")

def process_directory(directory):
    """Process all XML files in the directory."""
    for filename in os.listdir(directory):
        if filename.endswith('.xml'):
            process_file(os.path.join(directory, filename))

if __name__ == "__main__":
    import sys
    if len(sys.argv) == 2:
        process_file(sys.argv[1])
    elif len(sys.argv) == 3 and sys.argv[1] == '-d':
        process_directory(sys.argv[2])
    else:
        print("Usage:")
        print("  python xml_to_srt_converter.py <file.xml>")
        print("  python xml_to_srt_converter.py -d <directory>")
