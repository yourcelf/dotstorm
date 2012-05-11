import os

for filename in os.listdir("."):
    base, ext = os.path.splitext(filename)
    if ext == ".png" and "_small" not in base:
        os.system("convert %s -thumbnail 32x32 %s_small.png" % (filename, base))

