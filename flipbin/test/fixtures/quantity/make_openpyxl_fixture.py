# Regenerate openpyxl_v4_full.xlsx: v4_full.xlsx re-saved by openpyxl
# (inline strings, no sharedStrings.xml, absolute rels targets). BUG-01.
import openpyxl, os
d = os.path.dirname(os.path.abspath(__file__))
wb = openpyxl.load_workbook(os.path.join(d, 'v4_full.xlsx'))
wb.save(os.path.join(d, 'openpyxl_v4_full.xlsx'))
