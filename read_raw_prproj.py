
import gzip
import sys

def read_prproj_raw(filepath):
    try:
        with gzip.open(filepath, 'rt', encoding='utf-8') as f:
             # Read first 2000 chars to check structure
            content = f.read(2000)
            print(content)
            
            # Reset and search for file paths
            f.seek(0)
            print("\n--- SEARCHING FOR PATHS AND TIMECODE ---\n")
            count = 0
            for line in f:
                if any(x in line for x in ["Path", "FilePath", "MediaStart", "Timecode", "StartTime"]):
                    print(line.strip())
                    count += 1
                    if count > 50:
                        break
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    read_prproj_raw(sys.argv[1])
