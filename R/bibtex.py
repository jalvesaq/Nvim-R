import sys
import os
import re
from pybtex.database import parse_file

E = {} # Bib entries by bib file
M = {} # mtime of each bib file
D = {} # List of bib files of each markdown document

def get_authors(prsns):
    if 'author' in prsns:
        persons = prsns['author']
    elif 'editor' in prsns:
        persons = prsns['editor']
    else:
        return ''

    cit = ''
    isetal = False
    if len(persons) > 3:
        isetal = True

    for p in persons:
        lname = ' '.join(p.last())
        if lname == 'others':
            cit += ' et al.'
            break
        cit += ', ' + lname.title()
        if isetal:
            cit += ' et al.'
            break

    cit = re.sub('^, ', '', cit)

    return cit

def ParseBib(b):
    global E
    M[b] = os.path.getmtime(b)
    E[b] = {}

    try:
        bib = parse_file(b)
    except Exception as ERR:
        print('Error parsing ' + b + ': ' + str(ERR), file=sys.stderr)
        sys.stderr.flush()
        return

    for k in bib.entries:
        E[b][k] = {'citekey': k, 'title': '', 'year': '????'}
        E[b][k]['author'] = get_authors(bib.entries[k].persons)
        if 'title' in bib.entries[k].fields:
            E[b][k]['title'] = bib.entries[k].fields['title']
        if 'year' in bib.entries[k].fields:
            E[b][k]['year'] = bib.entries[k].fields['year']

def GetComplLine(k, e):
    return k + '\x09' + e['author'][0:40] + "\x09(" + e['year'] + ') ' + e['title']

def GetMatch(ptrn, d):
    for b in D[d]:
        if os.path.isfile(b):
            if b not in E or os.path.getmtime(b) > M[b]:
                ParseBib(b)
        else:
            D[d].remove(b)

    # priority level
    p1 = []
    p2 = []
    p3 = []
    p4 = []
    p5 = []
    p6 = []
    for b in D[d]:
        for k in E[b]:
            if E[b][k]['citekey'].lower().find(ptrn) == 0:
                p1.append(GetComplLine(k, E[b][k]))
            elif E[b][k]['author'].lower().find(ptrn) == 0:
                p2.append(GetComplLine(k, E[b][k]))
            elif E[b][k]['title'].lower().find(ptrn) == 0:
                p3.append(GetComplLine(k, E[b][k]))
            elif E[b][k]['citekey'].lower().find(ptrn) > 0:
                p4.append(GetComplLine(k, E[b][k]))
            elif E[b][k]['author'].lower().find(ptrn) > 0:
                p5.append(GetComplLine(k, E[b][k]))
            elif E[b][k]['title'].lower().find(ptrn) > 0:
                p6.append(GetComplLine(k, E[b][k]))
    resp = p1 + p2 + p3 + p4 + p5 + p6
    f = open(os.environ['NVIMR_TMPDIR'] + '/bibcompl', 'w')
    if resp:
        f.write('\n'.join(resp) + '\n')
        f.flush()
    f.close()
    print('let g:rplugin_bib_finished = 1')
    sys.stdout.flush()

def set_bibfiles(d, bibls):
    global D
    D[d] = []
    for b in bibls:
        if os.path.isfile(b):
            ParseBib(b)
            D[d].append(b)
        else:
            print('File "' + b + '" not found.', file=sys.stderr)
            sys.stderr.flush()

def loop():
    for line in map(str.rstrip, sys.stdin):
        if line[0] == "\x04":
            line = line.replace("\x04", "")
            d, b = line.split('\x05')
            set_bibfiles(d, b.split('\x06'))
        elif line[0] == "\x03":
            line = line.replace("\x03", "")
            ptrn, d = line.split('\x05')
            GetMatch(ptrn.lower(), d)

if __name__ == "__main__":
    set_bibfiles(sys.argv[1], sys.argv[2].split("\x06"))
    loop()
