
import sys
import os
import re
import sqlite3

# A lot of code was either adapted or plainly copied from citation_vim,
# by Rafael Schouten: https://github.com/rafaqz/citation.vim

class ZoteroEntries:

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
                    print('Collection "' + c + '" not found in Zotero database.',
                          file=sys.stderr)
                    sys.stderr.flush()


    def _load_zotero_data(self):
        self._m = os.path.getmtime(self._z)
        conn = sqlite3.connect(self._z)
        self._cur = conn.cursor()
        self._add_most_fields()
        self._add_collection()
        self._add_authors()
        self._add_type()
        self._add_note()
        self._add_tags()
        self._calculate_citekeys()
        conn.close()
        self._separate_by_collection()

    def _add_most_fields(self):
        fields_query = u"""
            SELECT items.itemID, fields.fieldName, itemDataValues.value, items.key
            FROM items, itemData, fields, itemDataValues
            WHERE
                items.itemID = itemData.itemID
                and itemData.fieldID = fields.fieldID
                and itemData.valueID = itemDataValues.valueID
            """
        self._cur.execute(fields_query)
        for item_id, field, value, key in self._cur.fetchall():
            if item_id not in self._t:
                self._t[item_id] = {'collection': None, 'alastnm': '', 'tags': []}
            self._t[item_id][field] = value

    def _add_collection(self):
        collection_query = u"""
            SELECT items.itemID, collections.collectionName
            FROM items, collections, collectionItems
            WHERE
                items.itemID = collectionItems.itemID
                and collections.collectionID = collectionItems.collectionID
            ORDER by collections.collectionName != "To Read",
                collections.collectionName
            """
        self._cur.execute(collection_query)
        for item_id, item_collection in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['collection'] = item_collection

    def _add_authors(self):
        author_query = u"""
            SELECT items.itemID, creatorTypes.creatorType, creators.lastName, creators.firstName
            FROM items, itemCreators, creators, creatorTypes
            WHERE
                items.itemID = itemCreators.itemID
                and itemCreators.creatorID = creators.creatorID
                and creators.creatorID = creators.creatorID
                and itemCreators.creatorTypeID = creatorTypes.creatorTypeID
            ORDER by itemCreators.ORDERIndex
            """
        self._cur.execute(author_query)
        #print('_add_authors', file=sys.stderr)
        for item_id, ctype, lastname, firstname in self._cur.fetchall():
            if item_id in self._t:
                if ctype in self._t[item_id]:
                    self._t[item_id][ctype] += [[lastname, firstname]]
                else:
                    self._t[item_id][ctype] = [[lastname, firstname]]
                # Special field for citation seeking
                if ctype == 'author':
                    self._t[item_id]['alastnm'] += ' ' + lastname
            #print(item_id, ctype, end='', file=sys.stderr)
            #print(self._t[item_id][ctype], file=sys.stderr)

    def _add_type(self):
        type_query = u"""
            SELECT items.itemID, itemTypes.typeName
            FROM items, itemTypes
            WHERE
                items.itemTypeID = itemTypes.itemTypeID
            """
        self._cur.execute(type_query)
        for item_id, item_type in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['etype'] = item_type

    def _add_note(self):
        note_query = u"""
            SELECT itemNotes.parentItemID, itemNotes.note
            FROM itemNotes
            WHERE
                itemNotes.parentItemID IS NOT NULL;
            """
        self._cur.execute(note_query)
        for item_id, item_note in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['note'] = item_note

    def _add_tags(self):
        tag_query = u"""
            SELECT items.itemID, tags.name
            FROM items, tags, itemTags
            WHERE
                items.itemID = itemTags.itemID
                and tags.tagID = itemTags.tagID
            """
        self._cur.execute(tag_query)
        for item_id, item_tag in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['tags'] += [item_tag]

    def _calculate_citekeys(self):
        #print('_calculate_citekeys', file=sys.stderr)
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
                #print(self._t[k]['author'], file=sys.stderr)
                lastname = self._t[k]['author'][0][0]
            else:
                lastname = ''
            lastname = re.sub('\W', '', lastname)
            titlew = re.sub('\W', '', titlew)
            key = lastname.lower() + '_' + year + '_' + titlew.lower()
            key = re.sub(' ', '', key)
            self._t[k]['citekey'] = key

    def _separate_by_collection(self):
        self._e = {}
        for k in self._t:
            if self._t[k]['collection'] not in self._e:
                self._e[self._t[k]['collection']] = {}
            self._e[self._t[k]['collection']][str(k)] = self._t[k]

    def _get_compl_line(self, k, e):
        line = e['citekey'] + '\x09'
        if 'author' in e:
            for a in e['author']:
                line += a[0] + ', '
        line = re.sub(', $', '', line)
        line += "\x09(" + e['year'] + ') ' + e['title']
        return line

    def GetMatch(self, ptrn, d):
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
                    p1.append(self._get_compl_line(k, self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) == 0:
                    p2.append(self._get_compl_line(k, self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) == 0:
                    p3.append(self._get_compl_line(k, self._e[c][k]))
                elif self._e[c][k]['citekey'].lower().find(ptrn) > 0:
                    p4.append(self._get_compl_line(k, self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) > 0:
                    p5.append(self._get_compl_line(k, self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) > 0:
                    p6.append(self._get_compl_line(k, self._e[c][k]))
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
        e['etype'] = re.sub('(.*)article', 'article-\\1', e['etype'].lower())
        e['etype'] = re.sub('booksection', 'chapter', e['etype'])
        e['etype'] = e['etype'].replace('conferencepaper', 'paper-conference')
        # Rename some fields
        if 'publicationTitle' in e:
            e['container-title'] = re.sub('"', '\\"', e.pop('publicationTitle'))
        elif 'bookTitle' in e:
            e['container-title'] = e.pop('bookTitle')
        if 'seriesTitle' in e:
            e['collection-title'] = e.pop('seriesTitle')
        if 'journalAbbreviation' in e:
            e['container-title-short'] = e.pop('journalAbbreviation')
        if 'place' in e:
            e['publisher-place'] = e.pop('place')
        if 'shortTitle' in e:
            e['title-short'] = e.pop('shortTitle')
        if 'extra' in e:
            e['note'] = re.sub('"', '\\"', e.pop('extra'))
        if 'numPages' in e:
            e['number-of-pages'] = e.pop('numPages')
        if 'numberOfVolumes' in e:
            e['number-of-volumes'] = e.pop('numberOfVolumes')
        if 'accessDate' in e:
            e['accessed'] = e.pop('accessDate')
        if 'abstractNote' in e:
            e['abstract'] = e.pop('abstractNote')
        if 'bookAuthor' in e:
            e['container-author'] = e.pop('bookAuthor')
        # Escape double quotes
        e['title'] = re.sub('"', '\\"', e['title'])
        if 'note' in e:
            e['note'] = re.sub('"', '\\"', e['note'])

        ref = '- type: ' + e['etype'] + '\n  id: ' + e['citekey'] + '\n'
        for aa in ['author', 'editor', 'contributor', 'translator', 
                   'container-author']:
            if aa in e:
                ref += '  ' + aa + ':\n'
                for last, first in e[aa]:
                    ref += '  - family: "' + last + '"\n'
                    ref += '    given: "' + first + '"\n'
        if 'date' in e:
            d = re.sub(' .*', '', e['date']).split('-')
            if d[0] != '0000':
                ref += '  issued:\n    year: ' + e['year'] + '\n'
                if d[1] != '00':
                    ref += '    month: ' + d[1] + '\n'
                if d[2] != '00':
                    ref += '    day: ' + d[2] + '\n'
        dont = ['etype', 'date', 'abstract', 'citekey', 'collection',
                'author', 'editor', 'contributor', 'translator',
                'alastnm', 'container-author', 'tags', 'year']
        for k in e:
            if k not in dont:
                ref += '  ' + k + ': "' + str(e[k]) + '"\n'
        return ref

    def GetYamlRefs(self, d, keys):
        ref = ''
        for c in self._d[d]:
            for r in self._e[c]:
                for k in keys:
                    if k == self._e[c][r]['citekey']:
                        ref += self._get_yaml_ref(self._e[c][r])
        if ref != '':
            ref = '---\nreferences:\n' + ref + '\n...\n\ndummy text\n'
        return ref


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
