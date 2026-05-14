import os
import struct

def check_16kb_alignment(file_path):
    with open(file_path, 'rb') as f:
        e_ident = f.read(16)
        if not e_ident.startswith(b'\x7fELF'):
            return True # Not an ELF file
        is_64_bit = e_ident[4] == 2
        endianness = '<' if e_ident[5] == 1 else '>'
        f.seek(28 if is_64_bit else 24)
        e_phoff = struct.unpack(endianness + ('Q' if is_64_bit else 'I'), f.read(8 if is_64_bit else 4))[0]
        
        f.seek(54 if is_64_bit else 44)
        e_phentsize = struct.unpack(endianness + 'H', f.read(2))[0]
        e_phnum = struct.unpack(endianness + 'H', f.read(2))[0]
        
        for i in range(e_phnum):
            f.seek(e_phoff + i * e_phentsize)
            buf = f.read(4)
            if len(buf) < 4: continue
            p_type = struct.unpack(endianness + 'I', buf)[0]
            if p_type == 1: # PT_LOAD
                if is_64_bit:
                    f.seek(e_phoff + i * e_phentsize + 48) # p_align is at offset 48 for 64-bit Program Header
                    p_align = struct.unpack(endianness + 'Q', f.read(8))[0]
                else:
                    f.seek(e_phoff + i * e_phentsize + 28) # p_align is at offset 28 for 32-bit Program Header
                    p_align = struct.unpack(endianness + 'I', f.read(4))[0]
                if p_align < 16384:
                    return False
    return True

unaligned = []
for root, dirs, files in os.walk(r'd:\COACHING APP\excellence\extracted_aab\base\lib'):
    if 'armeabi-v7a' in root or 'x86' in root and 'x86_64' not in root:
        continue
    for f in files:
        if f.endswith('.so'):
            path = os.path.join(root, f)
            if not check_16kb_alignment(path):
                unaligned.append(path)

if unaligned:
    print("Found unaligned .so files:")
    for p in set([os.path.basename(p) for p in unaligned]):
        print(p)
else:
    print("All .so files are 16KB aligned.")
