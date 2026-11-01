"""Reconstruit le bundle de localisation FR de Shroom and Gloom à partir des traductions.

Usage :
    python build_bundle.py <dossier_StandaloneWindows64_du_jeu> <dossier_traductions> <dossier_sortie>

- <dossier_StandaloneWindows64_du_jeu> : ...\\Shroom and Gloom_Data\\StreamingAssets\\aa\\StandaloneWindows64
  (la structure des tables est lue dans les fichiers du jeu ; aucun texte du jeu n'est stocké dans ce dépôt)
- <dossier_traductions> : dossier contenant Card.json, Card_Names.json, Enemy.json, UI.json, World.json
  au format {"CLE_DU_TEXTE": "texte français"}, et _textes_sans_cle.json au format {"id": "texte français"}

Dépendance : pip install UnityPy
"""
import copy
import json
import os
import sys

import UnityPy

SRC, TR, OUT = sys.argv[1:4]
SHARED = "localization-assets-shared_assets_all.bundle"
EN = "localization-string-tables-english(en)_assets_all.bundle"
FR = "localization-string-tables-french(fr)_assets_all.bundle"


def tables(bundle):
    res = {}
    for o in UnityPy.load(os.path.join(SRC, bundle)).objects:
        if o.type.name == "MonoBehaviour":
            d = o.read_typetree()
            res[d["m_Name"]] = d
    return res


# clé -> id, par collection (ex. "Card Names")
key_to_id = {}
for name, d in tables(SHARED).items():
    coll = name.replace(" Shared Data", "")
    key_to_id[coll] = {e["m_Key"]: e["m_Id"] for e in d["m_Entries"]}

# traductions : id -> texte FR
tr = {}
for coll, ids in key_to_id.items():
    path = os.path.join(TR, coll.replace(" ", "_") + ".json")
    if not os.path.exists(path):
        print(f"[!] {path} absent : collection {coll} laissée en anglais")
        continue
    for key, text in json.load(open(path, encoding="utf-8")).items():
        if key in ids:
            tr[ids[key]] = text
        else:
            print(f"[!] {coll}: clé inconnue ignorée (version du jeu différente ?) : {key}")

# Textes présents dans les tables mais sans clé (inutilisés par le jeu) : indexés par id.
extra = os.path.join(TR, "_textes_sans_cle.json")
if os.path.exists(extra):
    for i, text in json.load(open(extra, encoding="utf-8")).items():
        tr.setdefault(int(i), text)

en_tables = {n[:-3]: d for n, d in tables(EN).items()}  # "Card_en" -> "Card"

env = UnityPy.load(os.path.join(SRC, FR))
report = {}
for o in env.objects:
    if o.type.name != "MonoBehaviour":
        continue
    d = o.read_typetree()
    coll = d["m_Name"][:-3]
    en = en_tables[coll]
    rows, done, missing = [], 0, 0
    for e in en["m_TableData"]:
        row = copy.deepcopy(e)  # garde l'id et les métadonnées par entrée
        if e["m_Localized"] and tr.get(e["m_Id"]):
            row["m_Localized"] = tr[e["m_Id"]]
            done += 1
        elif e["m_Localized"]:
            missing += 1  # reste en anglais plutôt que vide
        rows.append(row)
    d["m_TableData"] = rows
    # Les marqueurs SmartFormat sont portés par la table : on reprend ceux de l'anglais.
    d["m_Metadata"] = copy.deepcopy(en["m_Metadata"])
    d["references"] = copy.deepcopy(en["references"])
    o.save_typetree(d)
    report[coll] = {"traduits": done, "restes_en_anglais": missing}

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, FR), "wb") as fh:
    fh.write(env.file.save(packer="lz4"))
print(json.dumps(report, indent=1, ensure_ascii=False))
