def maxXOR(L,R):
    P = L^R
    print P
    ret = 1
    while(P): # this one takes (m+1) = O(logR) steps
        ret <<= 1
        P >>= 1
    return (ret - 1)

print(maxXOR(int(input()),int(input())))