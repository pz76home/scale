#!/usr/bin/python




import sys
sum = 0

#f = open('/admin/scripts/test/list.report')
# If you need to use stdin instead
f = sys.stdin
for line in f:
    fields = line.strip().split()
    # Array indices start at 0 unlike AWK
    sum += int(fields[4])

print (sum/1024/1024/1024), "GB Usage"

#stdin reset
sys.stdin.seek(0)

#Python way to word count
f = sys.stdin
row = len(f.readlines())
print row, "Number of Files"
