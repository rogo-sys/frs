## CPU Util Spikes

  ### Effective_Interval_s
  Effective_Interval_s – näitab tegelikku mõõteintervalli sekundites, mille jooksul Zabbix kogus CPU kasutuse andmeid. Väärtus aitab hinnata andmete kogumise sagedust ja tagada tippude kestuse arvutuste täpsuse. (Kui andmeid pole, kasutatakse vaikimisi väärtust defaultne 60 sekundit.)

  ### Threshold_Percent – 
  Määrab protsendilise piiri, millest alates loetakse CPU kasutus „tipuks“. Väärtust kasutatakse piikide tuvastamiseks ja nende kestuse arvutamiseks.

  ### CPU_Spikes_Count
  Arv järjestikuseid tippude seeriaid, mis kestavad üle 60 sekundi (st kui system.cpu.util > threshold on järjest iga mõõtmise ajal).
  Üksikud, mitte järjestikused mõõtmised, kus cpu_util > threshold, arvesse ei lähe (kuid neid saab vaadata eraldi väljal – "Total_Samples_Above_Threshold").

  ### CPU_Spike_Max_s
  Sellise tipu maksimaalne kestus.

  ### CPU_Spikes_Total_s
  Kõigi tippude kogukestus. Üksikud mõõtmised, kus `cpu_util > threshold`, arvesse ei lähe (kuid neid saab vaadata eraldi väljal - "Total_Samples_Above_Threshold").

  Näited:

  |     | Host        | CPU_Spikes_Count | CPU_Spike_Max_s | CPU_Spikes_Total_s |
  | --- | ----------- | ---------------- | --------------- | ------------------ |
  | 1)  | LV-SIMS-SQL | 5                | 1020            | 3660               |
  | 2)  | OpenVAS-ext | 6                | 480             | 1260               |
  | 3)  | AD          | 2                | 600             | 720                |
  | 4)  | TS2019      | 1                | 180             | 180                |

  1. Oli 5 tippude seeriat, neist pikim kestis 1020 sekundit. Kõigi seeriate kogukestus oli 3660 sekundit.
  2. Oli 6 tippude seeriat. Tippude koguaeg – 1260 sekundit. Kõige pikem tipp kestis järjest 480 sekundit.
  3. Oli 2 tippude seeriat, pikim kestis 600 sekundit. Kõigi seeriate kogukestus – 720 sekundit (st teine kestis 120 sekundit).
  4. Oli üks tipp – 180 sekundit.

  ### History_Records_Count
  Näitab, mitu CPU mõõteandme kirjet Zabbix tagastas määratud ajavahemiku jooksul. Väärtus aitab hinnata, kas andmete hulk on piisav analüüsi tegemiseks ja kas andmekogumine toimib korrektselt.

  ### Total_Samples_Above_Threshold
  Mitu korda ajaloos esines väärtusi, mis ületasid läviväärtuse (Threshold). Just counter.
