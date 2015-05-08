# Enter your code here. Read input from STDIN. Print output to STDOUT

def getPalindromeSteps(my_word):
    steps = 0
    if my_word == my_word[::-1]:
        return steps
    else:
        f_index = 0
        e_index = len(my_word) - 1
        while f_index != e_index:
            if my_word[f_index] == my_word[e_index]:
                #move to the inner letters
                f_index += 1
                e_index -= 1
            else:
                temp_list = list(my_word)
                if temp_list[f_index] > temp_list[e_index]:
                    temp_list[f_index] = chr(ord(temp_list[f_index]) - 1)
                else:
                    temp_list[e_index] = chr(ord(temp_list[e_index]) - 1)
                steps += 1
                my_word = ''.join(temp_list)
            if my_word == my_word[::-1]:
                return steps


test_cases = int(input())

if test_cases == 0:
    print "Please enter a number greater than 0"
else:
    steps_list = []
    x = 0
    while x < test_cases:
        word_to_test = str(raw_input())
        steps_list.append(getPalindromeSteps(word_to_test))
        x+=1
    
    for steps in steps_list:
        print steps
