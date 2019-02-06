""" Class BibEntries and main function using the class """
import sys
import os
import re
from pybtex.database import parse_file
from nvimr import nvimr_cmd, nvimr_warn

class BibEntries:
    """ Create an object storing all references from bib files """

    E = {} # Bib entries by bib file
    M = {} # mtime of each bib file
    D = {} # List of bib files of each Rmarkdown document

    def __init__(self):
        self.SetBibfiles(sys.argv[1], sys.argv[2].split("\x06"))

    @classmethod
    def _get_authors(cls, prsns):
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

    def _parse_bib(self, b):
        self.M[b] = os.path.getmtime(b)
        self.E[b] = {}

        try:
            bib = parse_file(b)
        except Exception as ERR:
            nvimr_warn('Error parsing ' + b + ': ' + str(ERR))
            return

        for k in bib.entries:
            self.E[b][k] = {'citekey': k, 'title': '', 'year': '????'}
            self.E[b][k]['author'] = self._get_authors(bib.entries[k].persons)
            if 'title' in bib.entries[k].fields:
                self.E[b][k]['title'] = bib.entries[k].fields['title']
            if 'year' in bib.entries[k].fields:
                self.E[b][k]['year'] = bib.entries[k].fields['year']
            if 'file' in bib.entries[k].fields:
                self.E[b][k]['file'] = bib.entries[k].fields['file']

    @classmethod
    def _get_compl_line(cls, k, e):
        return k + '\x09' + e['author'][0:40] + "\x09(" + e['year'] + ') ' + e['title']

    def GetMatch(self, ptrn, d):
        """ Find citation key and save completion lines in temporary file """
        for b in self.D[d]:
            if os.path.isfile(b):
                if b not in self.E or os.path.getmtime(b) > self.M[b]:
                    self._parse_bib(b)
            else:
                self.D[d].remove(b)

        # priority level
        p1 = []
        p2 = []
        p3 = []
        p4 = []
        p5 = []
        p6 = []
        for b in self.D[d]:
            for k in self.E[b]:
                if self.E[b][k]['citekey'].lower().find(ptrn) == 0:
                    p1.append(self._get_compl_line(k, self.E[b][k]))
                elif self.E[b][k]['author'].lower().find(ptrn) == 0:
                    p2.append(self._get_compl_line(k, self.E[b][k]))
                elif self.E[b][k]['title'].lower().find(ptrn) == 0:
                    p3.append(self._get_compl_line(k, self.E[b][k]))
                elif self.E[b][k]['citekey'].lower().find(ptrn) > 0:
                    p4.append(self._get_compl_line(k, self.E[b][k]))
                elif self.E[b][k]['author'].lower().find(ptrn) > 0:
                    p5.append(self._get_compl_line(k, self.E[b][k]))
                elif self.E[b][k]['title'].lower().find(ptrn) > 0:
                    p6.append(self._get_compl_line(k, self.E[b][k]))
        resp = p1 + p2 + p3 + p4 + p5 + p6
        with open(os.environ['NVIMR_TMPDIR'] + '/bibcompl', 'w') as f:
            if resp:
                f.write('\n'.join(resp) + '\n')
        nvimr_cmd('let g:rplugin.bib_finished = 1')

    def SetBibfiles(self, d, bibls):
        """ Define which bib files each Rmarkdown document uses """
        self.D[d] = []
        for b in bibls:
            if b != '':
                if os.path.isfile(b):
                    self._parse_bib(b)
                    self.D[d].append(b)
                else:
                    nvimr_warn('File "' + b + '" not found.')

    def GetAttachment(self, d, citekey):
        """ Tell Vim what attachment is associated with the citation key """

        for b in self.D[d]:
            if os.path.isfile(b):
                if b not in self.E or os.path.getmtime(b) > self.M[b]:
                    self._parse_bib(b)
            else:
                self.D[d].remove(b)
                nvimr_cmd('let g:rplugin.last_attach = "nObIb:' + b + '"')
                return

        for b in self.D[d]:
            for k in self.E[b]:
                if self.E[b][k]['citekey'] == citekey:
                    if 'file' in self.E[b][k]:
                        nvimr_cmd('let g:rplugin.last_attach = "' + self.E[b][k]['file'] + '"')
                        return
                    nvimr_cmd('let g:rplugin.last_attach = "nOaTtAChMeNt"')
                    return
        nvimr_cmd('let g:rplugin.last_attach = "nOcItEkEy"')

if __name__ == "__main__":
    B = BibEntries()
    # Python 2.7 hangs here
    for S in map(str.rstrip, sys.stdin):
        if S[0] == "\x04":
            S = S.replace("\x04", "")
            D, L = S.split('\x05')
            B.SetBibfiles(D, L.split('\x06'))
        elif S[0] == "\x03":
            S = S.replace("\x03", "")
            Ptrn, D = S.split('\x05')
            B.GetMatch(Ptrn.lower(), D)
        elif S[0] == "\x02":
            S = S.replace("\x02", "")
            L = S.split('\x05')
            B.GetAttachment(L[0], L[1])
