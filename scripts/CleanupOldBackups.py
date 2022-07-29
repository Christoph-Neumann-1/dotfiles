#!/usr/bin/python
# This script finds old backups and deletes them

import os
import re
import datetime
#from turtle import back

# There is probably a already a function for this


def dateFromStr(str: str) -> datetime.date:
    assert re.match(r"\d{4}-\d{2}-\d{2}-\d{2}-\d{2}", str)
    return datetime.datetime(int(str[0:4]), int(str[5:7]), int(str[8:10]), int(str[11:13]), int(str[14:16]))

# This reverses the above function and is used to recreate the correct subvolume name


def strFromDate(date: datetime.date) -> str:
    return date.strftime("%Y-%m-%d-%H-%M")


backups = os.listdir('/.snapshots')
backups.sort(reverse=True)
# Use the last snapshot as a reference, so as to not delete all snapshots when not using the system for a long time
rLast = dateFromStr(re.sub(r'.+root-', '',
                           os.readlink('/.snapshots/root-last'), 1))
hLast = dateFromStr(re.sub(r'.+home-', '',
                           os.readlink('/.snapshots/home-last'), 1))
rBackups = [dateFromStr(item.replace('root-', ''))
            for item in backups if re.match(r'root-20\d{2}-\d{2}-\d{2}-\d{2}-\d{2}', item)]
hBackups = [dateFromStr(item.replace('home-', ''))
            for item in backups if re.match(r'home-20\d{2}-\d{2}-\d{2}-\d{2}-\d{2}', item)]
# This might be more efficient, since I am not sorting strings, but numbers
# rBackups.sort(reverse=True)
# hBackups.sort(reverse=True)

# Assert that there was no information loss
joined: list[str] = []
[joined.append("root-"+strFromDate(item)) for item in rBackups]
[joined.append("home-"+strFromDate(item)) for item in hBackups]
joined.append("root-last")
joined.append("home-last")
joined.sort(reverse=True)
assert joined == backups

# The last 5 backups are always kept
hBackups = hBackups[5:]
rBackups = rBackups[5:]


def applyRule1(startDate: datetime.datetime, numDays: int, backups: list[datetime.datetime]):
    return [item for item in backups if startDate -
            item > datetime.timedelta(days=numDays)]


def applyRule2(startDate: datetime.date, numWeeks: int, backups: list[datetime.datetime]):
    i = 0
    while i < len(backups):
        if startDate-datetime.date(backups[i].year, backups[i].month, backups[i].day) > datetime.timedelta(weeks=numWeeks):
            break
        day = backups[i].day
        backups.pop(i)
        while i < len(backups):
            if backups[i].day == day:
                i += 1
            else:
                break


hBackups = applyRule1(hLast, 5, hBackups)
rBackups = applyRule1(rLast, 5, rBackups)
applyRule2(datetime.date(
    hLast.year, hLast.month, hLast.day), 40, hBackups)
applyRule2(datetime.date(
    rLast.year, rLast.month, rLast.day), 40, rBackups)

# If this ever gets slow I can take advantage of the fact that it is sorted, meaning I can stop comparisons early, but that would mean stopping to use list comprehensions
# After that keep all backups for up to three days from the last backup
# hBackups = [item for item in hBackups if hLast - item
#             > datetime.timedelta(days=3)]

# # After that keep the last backup of the day for 4 weeks, then only the last weekly for 3 Months, the last monthly for a year, discard anything older than that
# hLastAsDate = datetime.date(hLast.year, hLast.month, hLast.day)
# i = 0
# while i < len(hBackups):
#     if hLastAsDate-datetime.date(hBackups[i].year, hBackups[i].month, hBackups[i].day) > datetime.timedelta(weeks=4):
#         break
#     day = hBackups[i].day
#     hBackups.pop(i)
#     while i < len(hBackups):
#         if hBackups[i].day == day:
#             i += 1
#         else:
#             break

# TODO: Clean up after 3 months

print("To be deleted:\nHome:")
[print(strFromDate(item)) for item in hBackups]
print("Root:")
[print(strFromDate(item)) for item in rBackups]
confirm = input("Are you sure you want to delete these backups? (y/n)")
if confirm == 'y':
    # TODO: use fewer system calls, a single call should suffice
    [os.system("btrfs su del /.snapshots/home-"+strFromDate(item))
     for item in hBackups]
    [os.system("btrfs su del /.snapshots/root-"+strFromDate(item))
     for item in rBackups]
    print("Deleted on main drive")
    if(os.system("mountpoint /backup") == 0):
        [os.system("btrfs su del /backup/.snapshots/home-"+strFromDate(item))
         for item in hBackups]
        [os.system("btrfs su del /backup/.snapshots/root-"+strFromDate(item))
         for item in rBackups]
        print("Deleted on backup drive")
    else:
        print("Backup drive not mounted, not deleted")
    # Check if drives have the same backups
    backups = os.listdir('/.snapshots')
    backups.sort(reverse=True)
    externalBkups = os.listdir('/backup/.snapshots')
    externalBkups.append("home-last")
    externalBkups.append("root-last")
    externalBkups.sort(reverse=True)
    if(externalBkups == backups):
        print("Backups are in sync")
    else:
        print("Backups are not in sync, please check manually")
elif confirm == 'n':
    print("Aborted")
else:
    print("Invalid input")
