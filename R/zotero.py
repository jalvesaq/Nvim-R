""" Class ZoteroEntries and executable using the class """
import sys
import os
import re
import sqlite3

# A lot of code was either adapted or plainly copied from citation_vim,
# written by Rafael Schouten: https://github.com/rafaqz/citation.vim
# Code and/or ideas were also adapted from zotxt, pypandoc, and pandocfilters.

class ZoteroEntries:
    """ Create an object storing all references from ~/Zotero/zotero.sqlite """

    # Conversion from zotero.sqlite to CSL types
    zct = {
        'artwork'             : 'graphic',
        'audioRecording'      : 'song',
        'blogPost'            : 'post-weblog',
        'bookSection'         : 'chapter',
        'case'                : 'legal_case',
        'computerProgram'     : 'book',
        'conferencePaper'     : 'paper-conference',
        'dictionaryEntry'     : 'entry-dictionary',
        'document'            : 'report',
        'email'               : 'personal_communication',
        'encyclopediaArticle' : 'entry-encyclopedia',
        'film'                : 'motion_picture',
        'forumPost'           : 'post',
        'hearing'             : 'bill',
        'instantMessage'      : 'personal_communication',
        'interview'           : 'interview',
        'journalArticle'      : 'article-journal',
        'letter'              : 'personal_communication',
        'magazineArticle'     : 'article-magazine',
        'newspaperArticle'    : 'article-newspaper',
        'note'                : 'manuscript',
        'podcast'             : 'broadcast',
        'presentation'        : 'speech',
        'radioBroadcast'      : 'broadcast',
        'statute'             : 'legislation',
        'tvBroadcast'         : 'broadcast',
        'videoRecording'      : 'motion_picture'}

    # Conversion from zotero.sqlite to CSL fields
    # FIXME: it's incomplete and accuracy isn't guaranteed.
    zcf = {
        'abstractNote'        : 'abstract',
        'accessDate'          : 'accessed',
        'applicationNumber'   : 'call-number',
        'archiveLocation'     : 'archive_location',
        'artworkMedium'       : 'medium',
        'artworkSize'         : 'dimensions',
        'audioFileType'       : 'medium',
        'blogTitle'           : 'container-title',
        'bookTitle'           : 'container-title',
        'callNumber'          : 'call-number',
        'code'                : 'container-title',
        'codeNumber'          : 'volume',
        'codePages'           : 'page',
        'codeVolume'          : 'volume',
        'conferenceName'      : 'event',
        'court'               : 'authority',
        'date'                : 'issued',
        'dictionaryTitle'     : 'container-title',
        'distributor'         : 'publisher',
        'encyclopediaTitle'   : 'container-title',
        'extra'               : 'note',
        'filingDate'          : 'submitted',
        'forumTitle'          : 'container-title',
        'history'             : 'references',
        'institution'         : 'publisher',
        'interviewMedium'     : 'medium',
        'issuingAuthority'    : 'authority',
        'legalStatus'         : 'status',
        'legislativeBody'     : 'authority',
        'libraryCatalog'      : 'source',
        'meetingName'         : 'event',
        'numPages'            : 'number-of-pages',
        'numberOfVolumes'     : 'number-of-volumes',
        'pages'               : 'page',
        'place'               : 'publisher-place',
        'priorityNumbers'     : 'issue',
        'proceedingsTitle'    : 'container-title',
        'programTitle'        : 'container-title',
        'programmingLanguage' : 'genre',
        'publicationTitle'    : 'container-title',
        'reporter'            : 'container-title',
        'runningTime'         : 'dimensions',
        'series'              : 'collection-title',
        'seriesNumber'        : 'collection-number',
        'seriesTitle'         : 'collection-title',
        'session'             : 'chapter-number',
        'shortTitle'          : 'title-short',
        'system'              : 'medium',
        'thesisType'          : 'genre',
        'type'                : 'genre',
        'university'          : 'publisher',
        'url'                 : 'URL',
        'versionNumber'       : 'version',
        'websiteTitle'        : 'container-title',
        'websiteType'         : 'genre'}

    def __init__(self):

        # Title words to be ignored
        self._w = os.getenv('BannedWords')
        if self._w is None:
            self._w = 'a an the some from on in to of do with'

        # Bib entries by collection
        self._e = {}

        # Temporary list of entries
        self._t = {}

        # Path of zotero.sqlite
        zsql = os.getenv('ZoteroSQLpath')
        if zsql is None:
            if os.path.isfile(os.getenv('HOME') + '/Zotero/zotero.sqlite'):
                zsql = os.getenv('HOME') + '/Zotero/zotero.sqlite'
        if zsql is None:
            print('The file zotero.sqlite3 was not found. Please, define the environment variable ZoteroSQLpath.', file=sys.stderr)
            sys.exit(1)

        self._z = zsql

        self._load_zotero_data()
        sys.stderr.flush()

        # List of collections for each markdown document
        self._d = {}
        self.SetCollections(os.getenv('RmdFile'), os.getenv('Collections'))

    def SetCollections(self, d, s):
        """ Define which Zotero collections each Rmarkdown document uses """

        if s is None:
            clist = ['']
        elif s.find('\x06') >= 0:
            clist = s.split('\x06')
        else:
            clist = [s]
        self._d[d] = []
        if clist == ['']:
            for k in self._e:
                self._d[d].append(k)
        else:
            self._d[d] = []
            for c in clist:
                if c in self._e:
                    self._d[d].append(c)
                else:
                    print('Collection "' + c + '" not found in Zotero database.', file=sys.stderr)
                    sys.stderr.flush()


    def _load_zotero_data(self):
        self._m = os.path.getmtime(self._z)

        # Make a copy of zotero.sqlite to avoid locks
        with open(self._z, 'rb') as f:
            b = f.read()
        with open(os.getenv('NVIMR_COMPLDIR') + '/copy_of_zotero.sqlite', 'wb') as f:
            f.write(b)

        conn = sqlite3.connect(os.getenv('NVIMR_COMPLDIR') + '/copy_of_zotero.sqlite')
        self._cur = conn.cursor()
        self._add_most_fields()
        self._add_collection()
        self._add_authors()
        self._add_type()
        self._add_note()
        self._add_tags() # Not used yet
        self._add_attachments()
        self._calculate_citekeys()
        self._separate_by_collection()
        conn.close()
        os.remove(os.getenv('NVIMR_COMPLDIR') + '/copy_of_zotero.sqlite')


    def _add_most_fields(self):
        query = u"""
            SELECT items.itemID, fields.fieldName, itemDataValues.value
            FROM items, itemData, fields, itemDataValues
            WHERE
                items.itemID = itemData.itemID
                and itemData.fieldID = fields.fieldID
                and itemData.valueID = itemDataValues.valueID
            """
        self._t = {}
        self._cur.execute(query)
        for item_id, field, value in self._cur.fetchall():
            if item_id not in self._t:
                self._t[item_id] = {'collection': None, 'alastnm': '', 'tags': []}
            self._t[item_id][field] = value

    def _add_collection(self):
        query = u"""
            SELECT items.itemID, collections.collectionName
            FROM items, collections, collectionItems
            WHERE
                items.itemID = collectionItems.itemID
                and collections.collectionID = collectionItems.collectionID
            ORDER by collections.collectionName != "To Read",
                collections.collectionName
            """
        self._cur.execute(query)
        for item_id, item_collection in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['collection'] = item_collection

    def _add_authors(self):
        query = u"""
            SELECT items.itemID, creatorTypes.creatorType, creators.lastName, creators.firstName
            FROM items, itemCreators, creators, creatorTypes
            WHERE
                items.itemID = itemCreators.itemID
                and itemCreators.creatorID = creators.creatorID
                and creators.creatorID = creators.creatorID
                and itemCreators.creatorTypeID = creatorTypes.creatorTypeID
            ORDER by itemCreators.ORDERIndex
            """
        self._cur.execute(query)
        for item_id, ctype, lastname, firstname in self._cur.fetchall():
            if item_id in self._t:
                if ctype in self._t[item_id]:
                    self._t[item_id][ctype] += [[lastname, firstname]]
                else:
                    self._t[item_id][ctype] = [[lastname, firstname]]
                # Special field for citation seeking
                if ctype == 'author':
                    self._t[item_id]['alastnm'] += ', ' + lastname

    def _add_type(self):
        query = u"""
            SELECT items.itemID, itemTypes.typeName
            FROM items, itemTypes
            WHERE
                items.itemTypeID = itemTypes.itemTypeID
            """
        self._cur.execute(query)
        for item_id, item_type in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['etype'] = item_type

    def _add_note(self):
        query = u"""
            SELECT itemNotes.parentItemID, itemNotes.note
            FROM itemNotes
            WHERE
                itemNotes.parentItemID IS NOT NULL;
            """
        self._cur.execute(query)
        for item_id, item_note in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['note'] = item_note

    def _add_tags(self):
        query = u"""
            SELECT items.itemID, tags.name
            FROM items, tags, itemTags
            WHERE
                items.itemID = itemTags.itemID
                and tags.tagID = itemTags.tagID
            """
        self._cur.execute(query)
        for item_id, item_tag in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['tags'] += [item_tag]

    def _add_attachments(self):
        query = u"""
            SELECT items.key, itemAttachments.parentItemID, itemAttachments.path
            FROM items, itemAttachments
            WHERE items.itemID = itemAttachments.itemID
            """
        self._cur.execute(query)
        for pKey, pId, aPath in self._cur.fetchall():
            self._t[pId]['attachment'] = pKey + ':' + aPath

    def _calculate_citekeys(self):
        ptrn = '^(' + ' |'.join(self._w) + ' )'
        for k in self._t:
            if 'date' in self._t[k]:
                year = re.sub(' .*', '', self._t[k]['date']).split('-')[0]
            else:
                year = ''
            self._t[k]['year'] = year
            if 'title' in self._t[k]:
                title = re.sub(ptrn, '', self._t[k]['title'].lower())
                title = re.sub('^[a-z] ', '', title)
                titlew = re.sub('[ ,;:\.!?].*', '', title)
            else:
                self._t[k]['title'] = ''
                titlew = ''
            if 'author' in self._t[k]:
                lastname = self._t[k]['author'][0][0]
            else:
                lastname = ''
            lastname = re.sub('\W', '', lastname)
            titlew = re.sub('\W', '', titlew)
            key = lastname.lower() + '_' + year + '_' + titlew.lower()
            key = re.sub(' ', '', key)
            self._t[k]['citekey'] = key
            if 'extra' in self._t[k] and re.search('^@\S+', self._t[k]['extra']):
                self._t[k]['citekey'] = re.sub('^@', '', self._t[k]['extra'])
                self._t[k]['citekey'] = re.sub('[\n ].*', '', self._t[k]['citekey'])
                self._t[k]['extra'] = re.sub('^@[^\n ]+', '', self._t[k]['extra'])
                self._t[k]['extra'] = self._t[k]['extra'].strip()
                if self._t[k]['extra'] == '':
                    self._t[k].pop('extra')


    def _separate_by_collection(self):
        self._cur.execute(u"SELECT itemID FROM deletedItems")
        d = []
        for item_id, in self._cur.fetchall():
            d.append(item_id)

        self._e = {}
        for k in self._t:
            if k in d or self._t[k]['etype'] == 'attachment':
                continue
            self._t[k]['alastnm'] = re.sub('^, ', '', self._t[k]['alastnm'])
            if self._t[k]['collection'] not in self._e:
                self._e[self._t[k]['collection']] = {}
            self._e[self._t[k]['collection']][str(k)] = self._t[k]

    @classmethod
    def _get_compl_line(cls, e):
        line = e['citekey'] + '\x09' + e['alastnm'] + "\x09(" + e['year'] + ') ' + e['title']
        return line

    def GetMatch(self, ptrn, d):
        """ Find citation key and save completion lines in temporary file """
        if os.path.getmtime(self._z) > self._m:
            self._load_zotero_data()

        # priority level
        p1 = []
        p2 = []
        p3 = []
        p4 = []
        p5 = []
        p6 = []
        for c in self._d[d]:
            for k in self._e[c]:
                if self._e[c][k]['citekey'].lower().find(ptrn) == 0:
                    p1.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) == 0:
                    p2.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) == 0:
                    p3.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['citekey'].lower().find(ptrn) > 0:
                    p4.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) > 0:
                    p5.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) > 0:
                    p6.append(self._get_compl_line(self._e[c][k]))
        resp = p1 + p2 + p3 + p4 + p5 + p6
        f = open(os.environ['NVIMR_TMPDIR'] + '/bibcompl', 'w')
        if resp:
            f.write('\n'.join(resp) + '\n')
            f.flush()
        f.close()
        print('let g:rplugin_bib_finished = 1')
        sys.stdout.flush()

    def _get_yaml_ref(self, e):
        # Fix the type
        if e['etype'] in self.zct:
            e['etype'] = e['etype'].replace(e['etype'], self.zct[e['etype']])
        # Escape quotes of all fields and rename some fields
        for f in e:
            if isinstance(e[f], str):
                e[f] = re.sub('"', '\\"', e[f])
            if f in self.zcf:
                e[self.zcf[f]] = e.pop(f)

        ref = '- type: ' + e['etype'] + '\n  id: ' + e['citekey'] + '\n'
        for aa in ['author', 'editor', 'contributor', 'translator',
                   'container-author']:
            if aa in e:
                ref += '  ' + aa + ':\n'
                for last, first in e[aa]:
                    ref += '  - family: "' + last + '"\n'
                    ref += '    given: "' + first + '"\n'
        if 'issued' in e:
            d = re.sub(' .*', '', e['issued']).split('-')
            if d[0] != '0000':
                ref += '  issued:\n    year: ' + e['year'] + '\n'
                if d[1] != '00':
                    ref += '    month: ' + d[1] + '\n'
                if d[2] != '00':
                    ref += '    day: ' + d[2] + '\n'
        dont = ['etype', 'issued', 'abstract', 'citekey', 'collection',
                'author', 'editor', 'contributor', 'translator',
                'alastnm', 'container-author', 'tags', 'year']
        for f in e:
            if f not in dont:
                ref += '  ' + f + ': "' + str(e[f]) + '"\n'
        return ref

    def GetYamlRefs(self, d, keys):
        """ Build a dummy Markdown documment with the references in the YAML header """

        ref = ''
        for c in self._d[d]:
            for r in self._e[c]:
                for k in keys:
                    if k == self._e[c][r]['citekey']:
                        ref += self._get_yaml_ref(self._e[c][r])
        if ref != '':
            ref = '---\nreferences:\n' + ref + '...\n\ndummy text\n'
        return ref

    def GetAttachment(self, cllctns, citekey):
        """ Tell Vim what attachment is associated with the citation key """

        if cllctns == '':
            clls = self._e.keys()
        else:
            clls = cllctns.split("\x06")
        sys.stderr.flush()
        for c in clls:
            if c not in self._e:
                self._cmd_to_vim('let g:rplugin_last_attach = "nOcLlCtN:' + c + '"')
                return
            else:
                for k in self._e[c]:
                    if self._e[c][k]['citekey'] == citekey:
                        if 'attachment' in self._e[c][k]:
                            self._cmd_to_vim('let g:rplugin_last_attach = "' + self._e[c][k]['attachment'] + '"')
                            return
                        self._cmd_to_vim('let g:rplugin_last_attach = "nOaTtAChMeNt"')
                        return
        self._cmd_to_vim('let g:rplugin_last_attach = "nOcItEkEy"')

    @classmethod
    def _cmd_to_vim(cls, cmd):
        print(cmd)
        sys.stdout.flush()


if __name__ == "__main__":
    Z = ZoteroEntries()
    for S in map(str.rstrip, sys.stdin):
        if S[0] == "\x04":
            S = S.replace('\x04', '')
            L = S.split('\x05')
            Z.SetCollections(L[0], L[1])
        elif S[0] == "\x03":
            S = S.replace("\x03", "")
            P, D = S.split('\x05')
            Z.GetMatch(P.lower(), D)
        elif S[0] == "\x02":
            S = S.replace("\x02", "")
            L = S.split('\x05')
            Z.GetAttachment(L[0], L[1])
