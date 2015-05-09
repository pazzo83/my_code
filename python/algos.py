"""ALGO EXERCISES"""

from collections import defaultdict, deque
from heapq import heapify, heappush, heappop
from itertools import count

#various graphs
a, b, c, d, e, f, g, h = range(8)
G_DAG = {'a' : ['b', 'f'], 'b':['c','d','f'], 'c':['d'], 'd':['e', 'f'], 'e': ['f'], 'f': []}
G_TRANSVERSE = {'a':set(['b', 'c', 'd']), 'b':set(['a', 'd']), 'c':set(['a', 'd']), 'd': set(['a', 'b', 'c']), 'e': set(['f', 'g']), 'f': set(['e', 'g']), 'g': set(['e', 'f']), 'h': set(['i']), 'i': set(['h'])}
N = [
    set([b, c, d, e, f]),  #a
    set([c, e]),           #b
    set([d]),              #c
    set([e]),              #d
    set([f]),              #e
    set([c, g, h]),        #f
    set([f, h]),           #g
    set([f, g])            #h
]
G_SCC = {'a': set(['c', 'b']), 'b': set(['d', 'i', 'e']), 'c': set(['d']), 'd': set(['a', 'h']), 'e': set(['f']), 'f': set(['g']), 'g': set(['e', 'h']), 'h': set(['i']), 'i': set(['h'])}
G_KRUSKAL = {0: {1:11, 2:13, 3:12}, 1:{0:11, 3:14}, 2:{0:13, 3:10}, 3:{0:12, 1:14, 2:10}}

def naive_max_perm(M, A=None):
    if A is None:
        A = set(range(len(M)))

    if len(A) == 1:
        return A

    B = set(M[i] for i in A)
    C = A - B
    if C:
        A.remove(C.pop())
        return naive_max_perm(M, A)

    return A

def counting_sort(A, key=lambda x: x):
    B, C = [], defaultdict(list)

    for x in A:
        C[key(x)].append(x)
    for k in range(min(C), max(C) + 1):
        B.extend(C[k])
    return B

def naive_topsort(G, S=None):
    if S is None:
        S = set(G)

    if len(S) == 1:
        return list(S)

    v = S.pop()
    seq = naive_topsort(G, S)
    min_i = 0

    for i, u in enumerate(seq):
        if v in G[u]:
            min_i = i + 1


    seq.insert(min_i, v)

    return seq

def top_sort(G):
    count = dict((u, 0) for u in G)

    for u in G:
        for v in G[u]:
            count[v] += 1

    Q = [u for u in G if count[u] == 0]
    S = []

    while Q:
        u = Q.pop()
        S.append(u)
        for v in G[u]:
            count[v] -= 1
            if count[v] == 0:
                Q.append(v)

    return S

#transveral functions
def walk(G, s, S=set()):
    P, Q = dict(), set()
    P[s] = None
    Q.add(s)
    while Q:
        u = Q.pop()
        for v in G[u].difference(P, S):
            Q.add(v)
            P[v] = u

    return P

def components(G):
    comp = []
    seen = set()
    for u in G:
        if u in seen:
            continue
        C = walk(G, u)
        seen.update(C)
        comp.append(C)
    return comp

def rec_dfs(G, s, S=None):
    if S is None:
        S = set()
    S.add(s)
    for u in G[s]:
        if u in S:
            continue
        rec_dfs(G, u, S)

    return S

def iter_dfs(G, s):
    S, Q = set(), []
    Q.append(s)

    while Q:
        u = Q.pop()
        if u in S:
            continue

        S.add(u)
        Q.extend(G[u])
        yield u

def traverse(G, s, qtype=set):
    S, Q = set(), qtype
    Q.add(s)

    while Q:
        u = Q.pop()
        if u in S:
            continue

        s.add(u)
        for v in G[u]:
            Q.add(v)

        yield u

#depth first search
def dfs(G, s, d, f, S=None, t=0):
    if S is None:
        S = set()

    d[S] = t
    t += 1
    S.add(s)
    for u in G[s]:
        if u in S:
            continue
        t = dfs(G, u, d, f, S, t)
    f[s] = t
    t += 1
    return t

def dfs_topsort(G):
    S, res = set(), []
    def recurse(u):
        if u in S:
            return
        S.add(u)
        for v in G[u]:
            print v
            recurse(v)
        res.append(u)
    for u in G:
        recurse(u)
    res.reverse()
    return res

def iddfs(G, s):
    yielded = set()

    def recurse(G, s, d, S=None):
        if s not in yielded:
            yield s
            yielded.add(s)

        if d == 0:
            return
        if S is None:
            S = set()
        S.add(s)
        for u in G[s]:
            if u in S:
                continue
            for v in recurse(G, u, d-1, S):
                yield v

    n = len(G)
    for d in range(n):
        if len(yielded) == n:
            break
        for u in recurse(G, s, d):
            yield u

def bfs(G, s):
    P, Q = {s: None, deque[s]}

    while Q:
        u = Q.popleft()
        for v in G[u]:
            if v in P:
                continue
            P[v] = u
            Q.append(v)

    return P

def tr(G):
    GT = {}
    for u in G:
        GT[u] = set()
    for u in G:
        for v in G[u]:
            GT[v].add(u)

    return GT

def scc(G):
    GT = tr(G)
    sccs, seen = [], set()
    for u in dfs_topsort(G):
        if u in seen:
            continue
        C = walk(GT, u, seen)
        seen.update(C)
        sccs.append(C)
    return sccs

#divide and conquer algos
def divide_and_conquer(S, divide, combine):
    if len(S) == 1:
        return S

    L, R = divide(S)
    A = divide_and_conquer(L, divide, combine)
    B = divide_and_conquer(R, divide, combine)

    return combine(A, B)

#binary tree searching
class Node(object):
    lft = None
    rgt = None
    def __init__(self, key, val):
        self.key = key
        self.val = val

def insert(node, key, val):
    if node is None:
        return Node(key, val)
    if node.key == key:
        node.val = val
    elif key < node.key:
        node.lft = insert(node.lft, key, val)
    else:
        node.rgt = insert(node.rgt, key, val)
    return node

def search(node, key):
    if node is None:
        raise KeyError
    if node.key == key:
        return node.val
    elif key < node.key:
        return search(node.lft, key)
    else:
        return search(node.rgt, key)

class Tree(object):
    root = None
    def __setitem__(self, key, val):
        self.root = insert(self.root, key, val)

    def __getitem__(self, key):
        return search(self.root, key)

    def __contains__(self, key):
        try:
            search(self.root, key)
        except KeyError:
            return False

        return True

#partition & select
def partition(seq):
    pivot, seq = seq[0], seq[1:]
    lo = [x for x in seq if x <= pivot]
    hi = [x for x in seq if x > pivot]

    return lo, pivot, hi

def select_part(seq, k):
    lo, pivot, hi = partition(seq)
    m = len(lo)

    if m == k:
        return pivot
    elif m < k:
        return select_part(hi, k - m - 1)
    else:
        return select_part(lo, k)

#quick sort
def quicksort(seq):
    if len(seq) <= 1:
        return seq
    lo, pivot, hi = partition(seq)

    return quicksort(lo) + [pivot] + quicksort(hi)

#mergesort
def mergesort(seq):
    mid = len(seq) // 2
    lft, rgt = seq[:mid], seq[mid:]

    if len(lft) > 1:
        lft = mergesort(lft)

    if len(rgt) > 1:
        mergesort(rgt)

    res = []
    while lft and rgt:
        if lft[-1] >= rgt[-1]:
            res.append(lft.pop())
        else:
            res.append(rgt.pop())

    res.reverse()
    return (lft or rgt) + res

#huffman algo
def huffman(seq, frq):
    num = count()
    trees = list(zip(frq, num, seq))
    heapify(trees)

    while len(trees) > 1:
        fa, _, a = heappop(trees)
        fb, _, b = heappop(trees)
        n = next(num)

        heappush(trees, (fa+fb, n, [a, b]))

    return trees[0][-1]

#kruskal
def naive_find(C,u):
    while C[u] != u:
        u = C[u]
    return u

def naive_union(C, u, v):
    u = naive_find(C, u)
    v = naive_find(C, v)
    C[u] = v

def naive_kruskal(G):
    E = [(G[u][v], u, v) for u in G for v in G[u]]
    T = set()
    C = dict((u, u) for u in G)
    for _, u, v in sorted(E):
        if naive_find(C, u) != naive_find(C, v):
            T.add((u, v))
            naive_union(C, u, v)

    return T

#better Kruskal
def find(C, u):
    if C[u] != u:
        C[u] = find(C, C[u]) #path compression

    return C[u]

def union(C, R, u, v):
    u, v = find(C, u), find(C, v)

    if R[u] > R[v]:
        C[v] = u
    else:
        C[u] = v

    if R[u] == R[v]:
        R[v] += 1

def kruskal(G):
    E = [(G[u][v], u, v) for u in G for v in G[u]]
    T = set()
    C, R = dict((u, u) for u in G), dict((u, 0) for u in G)
    for _, u, v in sorted(E):
        if find(C, u) != find(C, v):
            T.add((u, v))
            union(C, R, u, v)

    return T

#prim
def prim(G, s):
    P, Q = {}, [(0, None, s)]

    while Q:
        _, p, u = heappop(Q)
        if u in P:
            continue
        P[u] = p
        for v, w in G[u].items():
            heappush(Q, (w, u, v))

    return P