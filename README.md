# Pealkirjajaht

Igapäevane uudistemäng teleteksti stiilis. Iga päev ilmub uus küsimustepakk: 16 küsimust Eesti (ERR), välismaa (Yle, Al Jazeera, NPR) ja meelelahutusuudistest (Elu24).

Küsimuste tüübid:

- **Päris või võlts**: üks kolmest pealkirjast on välja mõeldud.
- **Lünk**: mis sõna päris pealkirjast puudub.
- **Kes ütles**: tsitaat ja neli nime.
- **Numbrimäng**: mida lähemale, seda rohkem punkte.
- **Kaart**: näita Eesti kaardil, kus see juhtus.

## Kuidas see töötab

- `index.html` on kogu mäng: staatiline leht, sisselogimist ei vaja.
- `editions/index.json` sisaldab väljaannete kuupäevade loendit (`{"dates": ["YYYY-MM-DD", …]}`).
- `editions/<YYYY-MM-DD>.json` on ühe päeva küsimustepakk.
- Mängija nimi, tulemused ja mänguajalugu salvestatakse tema brauserisse (localStorage).
- Ühine edetabel (päev / nädal / kõik ajad) on Supabase'is: `index.html`-is on konstandid `SB_URL` ja `SB_KEY` (avalik publishable/anon võti). Kui need on tühjad, töötab mäng ainult brauseri tulemustega.
  - Andmebaasi skeem ja funktsioonid: `supabase.sql` (käivita Supabase'i SQL Editoris). Tabelile otse ligi ei pääse; mäng kutsub ainult funktsioone `submit_score`, `set_player_name` ja `leaderboard`.
  - Mängija tuvastatakse brauseris loodud juhusliku ID-ga (`pj_pid`), sisselogimist pole. Arvesse läheb iga päeva esimene katse, ainult tänane ja eilne väljaanne; skoor peab jääma võimaliku maksimumi piiresse.
  - Sobimatu nime või tulemuse saab kustutada Supabase'i Table Editoris (tabel `scores`).
- `vendor/d3.min.js` on kaardi projektsiooni jaoks (d3 7.9.0, ISC-litsents, vt `vendor/d3-LICENSE.txt`).

Uue väljaande lisab igal hommikul Claude'i ajastatud ülesanne: see kirjutab uue JSON-faili kausta `editions/` ja lisab kuupäeva faili `index.json`.

## Väljaande JSON-i skeem

```json
{
  "date": "2026-10-06",
  "label": "Teisipäev, 6. oktoober 2026",
  "generatedAt": "2026-10-06T10:24:00+03:00",
  "source": "ERR, Elu24, Yle, Al Jazeera",
  "ticker": ["…8 päris pealkirja…"],
  "questions": [
    {"type": "fake", "cat": "sise", "src": "ERR", "prompt": "…", "options": ["…", "…", "…"], "answer": 1, "explain": "…", "url": "…"},
    {"type": "blank", "cat": "sport", "src": "ERR", "headline": "… ___ …", "options": ["…", "…", "…", "…"], "answer": 1, "explain": "…", "url": "…"},
    {"type": "who", "cat": "valis", "src": "Yle", "quote": "…", "options": ["…", "…", "…", "…"], "answer": 0, "explain": "…", "url": "…"},
    {"type": "number", "cat": "meelelahutus", "src": "Elu24", "prompt": "…", "answer": 150, "min": 10, "max": 2000, "decimals": 0, "unit": "osalist", "explain": "…", "url": "…"},
    {"type": "map", "cat": "sise", "src": "ERR", "prompt": "…", "lat": 57.7769, "lon": 26.0473, "place": "Valga", "explain": "…", "url": "…"}
  ]
}
```

Kategooriad (`cat`): `sise`, `valis`, `majandus`, `sport`, `kultuur`, `ilm`, `meelelahutus`.

## Avaldamine

Repo seadetes: **Settings → Pages → Build and deployment → Deploy from a branch → `main` / `(root)`**. Mäng on siis aadressil `https://siimmannik.github.io/pealkirjad/`.

Kohalikuks proovimiseks: `python3 -m http.server` repo kaustas ja ava `http://localhost:8000/`.
