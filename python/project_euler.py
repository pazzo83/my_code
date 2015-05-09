"""
FUNCTIONS TO HELP WITH PROJECT EULER
"""
import math
import itertools

import numpy as np

ones = {
    1: 'one',
    2: 'two',
    3: 'three',
    4: 'four',
    5: 'five',
    6: 'six',
    7: 'seven',
    8: 'eight',
    9: 'nine'
}

tens = {
    10: 'ten',
    11: 'eleven',
    12: 'twelve',
    13: 'thirteen',
    14: 'fourteen',
    15: 'fifteen',
    16: 'sixteen',
    17: 'seventeen',
    18: 'eighteen',
    19: 'nineteen',
    20: 'twenty',
    30: 'thirty',
    40: 'forty',
    50: 'fifty',
    60: 'sixty',
    70: 'seventy',
    80: 'eighty',
    90: 'ninety'
}

#for counting days
WEEK = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
MONTHS_DAYS = {
    'Jan': 31,
    'Feb': 28,
    'Mar': 31,
    'Apr': 30,
    'May': 31,
    'Jun': 30,
    'Jul': 31,
    'Aug': 31,
    'Sep': 30,
    'Oct': 31,
    'Nov': 30,
    'Dec': 31
}

GREG_START_DAY_IDX = 5
GREG_START_YEAR = 1582



def max_prime_factor(n):
    largest_factor = 1
    i = 2

    #i is a possible smallest factor of the remaining number n
    #if i*i > n, then n is either 1 or a prime number
    while i * i <= n:
        if n % i == 0:
            largest_factor = i

            #divide by the highest possible power of the found factor
            while n % i == 0:
                n //= i
        i = 3 if i == 2 else i + 2

    if n > 1:
        #n is a prime number and therefore the largest prime factor of the original number
        largest_factor = n

    return largest_factor

def get_prime_factors(n):
    prime_fac = set()
    d = 2

    while d * d <= n:
        while n % d == 0:
            prime_fac.add(d)
            n //= d
        d = 3 if d == 2 else d + 2

    if n > 1:
        prime_fac.add(n)

    return prime_fac

def get_divisors(n, remove_self=False):
    i = 1
    divisors = set()
    while i < math.sqrt(n) + 1:
        if n % 1 == 0:
            divisors.add(i)

            if i is not n/i:
                divisors.add(n/i)

        i += 1
    if remove_self:
        divisors.remove(n)

    return divisors

def is_palindrome(num):
    return str(num) == str(num)[::-1]

def find_largest_palindrome_three_digit():
    multiples = ((a, b) for a, b in itertools.product(xrange(100,999), repeat=2) if is_palindrome(a*b))
    return max(multiples, key=lambda (a, b): a * b)

def gcd(a, b):
    """Return the greatest common divisor using Euclid's Algorithm"""
    while b:
        a, b = b, a % b
    return a

def lcm(a, b):
    """Return lowest common multiple"""
    return a * b // gcd(a, b)

def lcmm(*args):
    """return lcm of args"""
    return reduce(lcm, args)

#primes - Eratosthenes Sieves
def primes_sieve1(nth_prime):
    limit = int((nth_prime * math.log1p(nth_prime)) + (nth_prime * math.log1p(math.log1p(nth_prime))))
    print limit

    a = [True] * limit
    a[0] = a[1] = False
    count = 0

    for (i, isprime) in enumerate(a):
        if isprime:
            count += 1
            if count == nth_prime:
                return i
            if float(i * i) < limit:
                for n in range(i * i, limit, i):
                    a[n] = False
    return None

def primes_sieve2(limit):
    a = [True] * limit
    a[0] = a[1] = False

    for (i, isprime) in enumerate(a):
        if isprime:
            yield i
            if float(i * i) < limit:
                for n in xrange(i * i, limit, i):
                    a[n] = False

def find_largest_seq_product(num, len_seq):
    #convert to str first
    num_str = str(num)
    max_product = 0

    for x in range(len(num_str)):
        list_nums = [int(y) for y in num_str[x:len_seq * x]]
        product = reduce(lambda x, y: x * y, list_nums)
        if product > max_product:
            max_product = product

    return max_product


def gen_prime_pyth_trips(limit=None):
    u = np.mat(' 1 2 2; -2 -1 -2; 2 2 3')
    a = np.mat(' 1 2 2; 2 1 2; 2 2 3')
    d = np.mat(' -1 -2 -2; 2 1 2; 2 2 3')

    uad = np.array([u, a, d])
    m = np.array([3, 4, 5])

    while m.size:
        m = m.reshape(-1, 3)
        if limit:
            m = m[m[:, 2] <= limit]

        for x in m:
            yield x

        m = np.dot(m, uad)

def gen_all_pyth_trips(limit):
    for prim in gen_prime_pyth_trips(limit):
        i = prim
        for _ in range(limit//prim[2]):
            print i
            i = i + prim

#finds python triple that equals a certain number
def gen_all_pyth_trips2(target):
    for prim in gen_prime_pyth_trips():
        i = prim
        while np.sum(i) <= target:
            if np.sum(i) == target:
                return i
            i = i + prim

def product_in_direction(grid, start, direction, steps):
    x0, y0 = start
    dx, dy = direction

    if not (0 <= y0                    < len(grid) and
            0 <= y0 + (steps - 1) * dy < len(grid) and
            0 <= x0                    < len(grid) and
            0 <= x0 + (steps - 1) * dy < len(grid[y0])):
        return 0
    product = 1
    for n in range(steps):
        product *= grid[y0 + n*dy][x0 * n*dx]
    return product

def calculate_max_product_grid(grid, steps):
    largest = 0
    for y in range(len(grid)):
        for x in range(len(grid[y])):
            largest = max(
                product_in_direction(grid, (x, y),             (1, 0), steps), #horizontal
                product_in_direction(grid, (x, y),             (0, 1), steps), #vertical
                product_in_direction(grid, (x, y),             (1, 1), steps), #right diag
                product_in_direction(grid, (x, y+(steps - 1)), (1, -1), steps), #left diag
                largest,
            )
    return largest

def collatz_seq(max_num):
    longest_seq = []

    def even_operation(n):
        return n/2

    def odd_operation(n):
        return 3*n + 1

    for i in range(2, max_num):
        res = i
        temp_seq = []
        temp_seq.append(res)
        while res > 1:
            if res % 2 == 0:
                res = even_operation(res)
            else:
                res = odd_operation(res)

            temp_seq.append(res)

        if len(temp_seq) > len(longest_seq):
            longest_seq = temp_seq

    return longest_seq

def LatticePath(down, right):
    if down == 0 or right == 0:
        return 1
    else:
        return LatticePath(down - 1, right) + LatticePath(down, right - 1)

def LatticePath_v2(down, right):
    return math.factorial(down + right) / (math.factorial(down)**2)

def LatticePath_v3(down, right):
    n = down * 2
    k = down
    return math.factorial(n) / (math.factorial(k) * math.factorial(n - k))

def written_ones(n):
    ones_num = n % 10
    return ones[ones_num]

def written_tens(n):
    tens_num = (n % 100) - (n % 10)
    return tens[tens_num]

def written_number(n):
    if n < 10:
        return ones[n]
    elif n < 100:
        if n % 10 == 0 or n < 20:
            return tens[n]
        else:
            return written_tens(n) + written_ones(n)
    elif n < 1000:
        if n % 100 == 0:
            return ones[n / 100] + ' hundred'
        else:
            hunds = n // 100
            base_tens = n - (hunds * 100)
            if base_tens % 10 == 0 or 10 <= base_tens < 20:
                return ones[hunds] + ' hundred and ' + tens[base_tens]
            else:
                if base_tens >= 20:
                    return ones[hunds] + ' hunrdred and ' + written_tens(n) + ' ' + written_ones(n)
                else:
                    #base tens is the ones digit
                    return ones[hunds] + ' hundred and ' + ones[base_tens]
    else:
        return 'one thousand'

def create_tri_string(tri):
    tri_str = ''
    max_width = len(tri[-1]) + (len(tri[-1]) -1)

    def convert_num_to_str(num):
        if num < 10:
            return '0' + str(num)
        else:
            return str(num)

    for row in tri:
        how_much_white_space = max_width - (len(row) + (len(row) - 1))
        tri_row = ' '*(how_much_white_space / 2)
        tri_row += ' '.join(map(convert_num_to_str, row))
        tri_row += ' '*(how_much_white_space / 2)
        tri_row += '\n'

        tri_str += tri_row

    return tri_str

def solve_triangle_path(tri, debug=False):
    while len(tri) > 1:
        t0 = tri.pop()
        t1 = tri.pop()
        tri.append([max(t0[i], t0[i * 1]) for i, t in enumerate(t1)])
        if debug:
            tri_str = create_tri_string(tri)
            print tri_str
    return tri

def count_days_start_month(day_index, start_year, end_year):
    # 1 Jan 1582 - first year of the Gregorian Calendar
    orig_start_day_indx = GREG_START_DAY_IDX
    orig_start_year = GREG_START_YEAR

    matched_days = []

    def is_leap(yr):
        if yr % 100 == 0:
            if yr % 400 == 0:
                return True
        elif yr % 4 == 0:
            return True
        return False

    #get to the start year Jan 1
    for year in range(orig_start_year, end_year):
        leap_year = is_leap(year)

        if leap_year:
            year_days = 366
        else:
            year_days = 365
        end_indx = (orig_start_day_indx + (year_days - 1)) % 7
        orig_start_day_indx = end_indx + 1 if end_indx < 6 else 0

    main_start_indx = orig_start_day_indx
    print main_start_indx

    for year in range(start_year, end_year):
        leap_year = is_leap(year)
        for month in MONTHS:
            if main_start_indx == day_index:
                matched_days.append('{0}: {1}'.format(year, month))
            if month == 'Feb' and leap_year:
                days = 29
            else:
                days = MONTHS_DAYS[month]

            end_indx = (main_start_indx + (days - 1)) % 7
            main_start_indx = end_indx + 1 if end_indx < 6 else 0

    print year
    print main_start_indx

    return matched_days

def find_amicable_nums(limit):
    amicables = []

    for x in range(2, limit):
        divisors_a = get_divisors(x, remove_self=True)
        divisors_a_sum = sum(divisors_a)

        if x != divisors_a_sum and set([x, divisors_a_sum]) not in amicables:
            divisors_b = get_divisors(divisors_a_sum, remove_self=True)
            divisors_b_sum = sum(divisors_b)
            if x == divisors_b_sum:
                match_set = set([x, divisors_a_sum])
                amicables.append(match_set)

    return amicables

def calc_score(name):
    #we are going to use ascii conversion
    #lowercase!!
    name = name.lower()

    def convert_score(char):
        #96 because we want a 1-based score (e.g. a = 1, b = 2, etc)
        return ord(char) - 96

    return sum(map(convert_score, list(name)))

def names_scores(data):
    #get alpha sort
    sorted_data = sorted(data)

    #get scores
    scores = 0

    for i, x in enumerate(sorted_data):
        score = (i + 1) * calc_score(x)
        scores += score

    return scores

def non_abundant_sums():
    #by definition
    upper_limit = 28123
    abun_nums = set()
    sum_abun_nums = set()
    non_sum_abun_nums = set()

    for x in range(1, upper_limit):
        #figure out abun
        x_div = get_divisors(x, remove_self=True)
        x_div_sum = sum(x_div)

        if x_div_sum > x:
            abun_nums.add(x)

            #add all possible abun_sum combos
            for num in abun_nums:
                sum_abun_nums.add(x+num)
        if x not in sum_abun_nums:
            non_sum_abun_nums.add(x)

    return non_sum_abun_nums

def get_factorial_base(n):
    num = n
    divisor = 1
    fact_base = []
    while num > 0:
        fact_base.append(num % divisor)
        num //= divisor
        divisor += 1
    fact_base.reverse()

    return fact_base

def get_xth_lexicographical_perm(x, num_seq):
    fact_base = get_factorial_base(x)
    seq = num_seq
    if len(seq) > len(fact_base):
        diff = len(seq) - len(fact_base)
        fact_base.extend([0]*diff)
    pos = 0
    perm = []
    while seq:
        perm.append(seq.pop(fact_base[pos]))
        pos += 1

    return perm

def special_fib(digit_size):
    a, b = 0, 1
    count = 0
    while a <= digit_size:
        a, b = b, a + b
        count += 1

    return count, a

def recurring_decimal(L):
    for d in list(primes_sieve2(L))[::-1]:
        period = 1
        while pow(10, period, d) != 1:
            period += 1
        if d - 1 == period:
            break

    return d

















