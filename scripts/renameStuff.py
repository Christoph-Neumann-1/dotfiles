

import os
import re

files = os.listdir('/backup/.snapshots/')
[os.system("btrfs su del /backup/.snapshots/"+item)
 for item in files if re.search(r'T', item)]
