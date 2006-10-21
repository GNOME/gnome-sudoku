import string
import sudoku

SEP = '|'
perms = {}

# def add_to_perm_dic (f):
#     def _ (arg):
#         key = tuple(tuple(a) for a in arg)
#         print 'key  = ',key
#         if perms.has_key(key):
#             return perms[key]
#         else:
#             ret = f(arg)
#             perms[key] = ret
#             return ret
#     return _

# #@add_to_perm_dic
# def get_permutations (possible_values):
#     if len(possible_values) == 1:
#         return [[p] for p in possible_values[0]]
#     else:
#         retval = []
#         other_permutations = get_permutations(possible_values[1:])
#         for perm in possible_values[0]:
#             retval.extend([[perm]+poss for poss in other_permutations])
#         return retval

# def get_n_for_permutation (possible_values, vals):
#     perms = [tuple(l) for l in get_permutations(possible_values)]
#     return perms.index(vals)

# def get_permutation_for_n (possible_values, n):
#     perms = [tuple(l) for l in get_permutations(possible_values)]
#     return perms[n]
    
# def get_n_permutations (possible_values):
#     nn = [len(pv) for pv in possible_values]
#     ret = nn.pop()
#     while nn:
#         ret = ret * nn.pop()
#     return ret
    
# my_letters = list('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()[]{}-_.:?')
# WORD_LENGTH = 2
# my_letters = [a[0]+a[1] for a in get_permutations([my_letters,my_letters])]
# my_letters.reverse()
# zero_to_code = {}
# code_to_zero = {}
# max_zero_count = 10
# for n in range(1,max_zero_count+1):
#     letter = my_letters.pop()
#     zero_to_code[n] = letter
#     code_to_zero[letter] = n

# my_letters.reverse()
# #my_letters = [str(n) for n in range(10)]+my_letters

# max_permutations = len(my_letters)
# chunk_length = 2

# def convert_to_combo (vals, possible_vals):
#     perms = get_n_permutations(possible_vals)
#     if perms >= max_permutations:
#         return ''.join(str(v) for v in vals)
#     else:
#         n = get_n_for_permutation(possible_vals,tuple(vals))
#         return my_letters[n]

# # These are convenient methods to put and remove spaces between
# # "words" to prevent overlap errors...
# def divide_words (name):
#     n = ''
#     for e,letter in enumerate(name):
#         if e/2 and e/2==e/2.0: n+=SEP+letter
#         else: n += letter
#     return n

# def undivide_words (name): return name.replace(SEP,'')

# def name_sudoku (grid, range_args=[(9,),(9,)]):
#     my_grid = sudoku.SudokuGrid()
#     combinations = 1
#     queued_possible = []
#     queued = []
#     name = ''
#     tups = []
#     for y in range(*range_args[0]):
#         for x in range(*range_args[1]):
#             tups.append((x,y))
#     tups.reverse()
#     while tups or queued:
#         if tups:
#             x,y = tups.pop()
#             is_last_time = False
#             possible = my_grid.possible_values(x,y)
#             possible.add(0)
#             possible = list(possible)
#             npossible = len(possible)
#         else:
#             is_last_time = True
#             npossible = 1        
#         if is_last_time or (npossible * combinations) > max_permutations:
#             chunk_name = my_letters[get_n_for_permutation(queued_possible,tuple([q[2] for q in queued]))]
#             for xx,yy,vv in queued:
#                 if vv: my_grid.add(xx,yy,vv)
#             print 'compressing',[q[2] for q in queued],'to',chunk_name                
#             name += chunk_name
#             queued = []
#             queued_possible = []
#             combinations = 1
#         if not is_last_time:
#             val = grid._get_(x,y)
#             queued.append((x,y,val))
#             queued_possible.append(possible)
#             combinations = npossible * combinations
#     name = divide_words(name)
#     for n in range(max_zero_count,0,-1):
#         name = name.replace(((my_letters[0]+SEP)*n)[:-1],zero_to_code[n])
#     return undivide_words(name)

# def name_sudoku_shortly (grid, n=9):
#     name1 = name_sudoku(grid,range_args=((n,),(n,))); l1 = len(name1)
#     name2 = name_sudoku(grid,range_args=((n-1,0,-1),(n,))); l2 = len(name2)
#     name3 = name_sudoku(grid,range_args=((n,),(n-1,0,-1))); l3 = len(name3)
#     name4 = name_sudoku(grid,range_args=((n-1,0,-1),(n-1,0,-1))); l4 = len(name4)
#     print 'generated 4 names:'
#     print name1; print name2; print name3; print name4
#     for name,length in [(name1,l1),(name2,l2),(name3,l3),(name4,l4)]:
#         if length <= l1 and length <= l2 and length <= l3 and length <= l4:
#             print 'returning',name
#             return name

# def get_sudoku_from_name (name):
#     # Decompress 0s...
#     name = divide_words(name)
#     for n in range(max_zero_count,0,-1):
#         name = name.replace(zero_to_code[n],my_letters[0]*n)
#     name = undivide_words(name)
#     my_grid = sudoku.SudokuGrid()
#     combinations = 1
#     queued = []
#     for y in range(9):
#         for x in range(9):
#             possible = my_grid.possible_values(x,y)
#             possible.add(0)
#             possible = list(possible)
#             npossible = len(possible)
#             if (npossible * combinations) > max_permutations:
#                 # Take care of queue
#                 chunk_name = my_letters[get_n_for_permutation(queued_possible,tuple(queued))]
#             queued.append((x,y,possible))
            
            
zero_sub = {
    2:'a',3:'b',4:'c',5:'d',6:'e',7:'f',8:'g',9:'h',10:'i',
    11:'j',12:'k',13:'l',14:'m',15:'n',16:'o',17:'p',18:'q',
    19:'r',20:'s',21:'t',22:'u',23:'v',24:'w',25:'x',26:'y',27:'z'
    }

letter_to_sub = {
    '01':'A',
    '02':'B',
    '03':'C',
    '04':'D',
    '05':'E',
    '06':'F',
    '07':'G',
    '08':'H',
    '09':'I',
    '11':'J',
    '12':'K',
    '13':'L',
    '14':'M',
    '15':'N',
    '16':'P',
    '17':'Q',
    '18':'R',
    '19':'S',
    '20':'T',
    '21':'U',
    '22':'V',
    '23':'W',
    '24':'X',
    '25':'Y',
    '26':'Z',
    '27':'+',
    '28':'-',
    '29':'_',
    '31':'~',
    '32':'.',
    }

def name_sudoku (sudoku):
    ret = sudoku.to_string().replace(' ','')
    for n in range(27,1,-1):
        ret = ret.replace('0'*n,zero_sub[n])            
    for numbers,sub in letter_to_sub.items():
        ret = ret.replace(numbers,sub)    
    return ret
    
def get_sudoku_from_name (name):
    for n in range(27,1,-1):
        name = name.replace(zero_sub[n],'0'*n)
    for numbers,sub in letter_to_sub.items():
        name = name.replace(sub,numbers)
    sg = sudoku.SudokuGrid()
    n = 0
    for y in range(9):
        for x in range(9):
            if name[n]!='0':
                sg.add(x,y,int(name[n]))
            n+=1
    return sg
                   
