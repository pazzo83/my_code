__author__ = 'christopheralexander_nmp'

# Head ends here
def lonelyinteger(b):
    answer = 0
    seen = set()
    unique = set()

    for n in b:
        if n in seen:
            unique.remove(n)
        else:
            seen.add(n)
            unique.add(n)
    answer = list(unique)[0]
    return answer
# Tail starts here
if __name__ == '__main__':
    a = int(input())
    b = map(int, input().strip().split(" "))
    print(lonelyinteger(b))