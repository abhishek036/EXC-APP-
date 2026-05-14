import os
import struct
import zipfile
import shutil

def is_16kb_aligned(filepath):
    # Parse ELF program headers directly
    try:
        with open(filepath, 'rb') as f:
            e_ident = f.read(16)
            if e_ident[:4] != b'\x7fELF':
                return True # Not an ELF file
                
            is_64bit = e_ident[4] == 2
            if not is_64bit:
                return True # Only care about 64-bit
                
            endian = '<' if e_ident[5] == 1 else '>'
            
            # Read ELF header (64-bit)
            # e_type, e_machine, e_version, e_entry, e_phoff, e_shoff, e_flags, e_ehsize, e_phentsize, e_phnum
            f.seek(16)
            elf_hdr = f.read(48)
            e_phoff = struct.unpack_from(endian + 'Q', elf_hdr, 16)[0]
            e_phentsize = struct.unpack_from(endian + 'H', elf_hdr, 38)[0]
            e_phnum = struct.unpack_from(endian + 'H', elf_hdr, 40)[0]
            
            # Read program headers
            f.seek(e_phoff)
            for _ in range(e_phnum):
                phdr = f.read(e_phentsize)
                p_type = struct.unpack_from(endian + 'I', phdr, 0)[0]
                if p_type == 1: # PT_LOAD
                    p_align = struct.unpack_from(endian + 'Q', phdr, 48)[0]
                    if p_align < 16384:
                        return False
        return True
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return True

print("Extracting AAB...")
aab_path = r"d:\COACHING APP\excellence\build\app\outputs\bundle\release\app-release.aab"
extract_dir = r"d:\COACHING APP\excellence\temp_aab"

if os.path.exists(extract_dir):
    shutil.rmtree(extract_dir)
os.makedirs(extract_dir)

with zipfile.ZipFile(aab_path, 'r') as zip_ref:
    zip_ref.extractall(extract_dir)

unaligned = []
lib_dir = os.path.join(extract_dir, "base", "lib")

if not os.path.exists(lib_dir):
    print("No native libraries found in AAB!")
else:
    for root, dirs, files in os.walk(lib_dir):
        if 'armeabi-v7a' in root or 'x86' in root and 'x86_64' not in root:
            continue # Skip 32-bit
        for f in files:
            if f.endswith('.so'):
                path = os.path.join(root, f)
                if not is_16kb_aligned(path):
                    arch = os.path.basename(root)
                    unaligned.append(f"{arch}/{f}")

    if not unaligned:
        print("✅ SUCCESS: All 64-bit .so files are 16KB aligned!")
    else:
        print("❌ FAILED: Found unaligned 64-bit .so files:")
        for u in set(unaligned):
            print(f"   - {u}")

# Clean up
shutil.rmtree(extract_dir)
