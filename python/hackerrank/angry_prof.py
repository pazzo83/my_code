__author__ = 'christopheralexander_nmp'

def class_cancelled(students, cancel_limit):
    on_time = [y for y in students if y <= 0]
    #print(on_time)
    if len(on_time) < cancel_limit:
        return 'YES'
    else:
        return 'NO'

num_tests = int(input())

for x in range(num_tests):
    num_students, cancel_limit = map(int, input().strip().split(' '))
    students = map(int, input().strip().split(' '))
    cancelled = class_cancelled(students, cancel_limit)
    print(cancelled)