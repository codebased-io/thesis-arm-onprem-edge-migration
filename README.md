# Codebased Oy:n ARM64-pohjainen on-premises-reunalaskentaympäristö

Tämä repositorio sisältää Codebased Oy:lle toteutetun ARM64-pohjaisen on-premises-reunalaskentaympäristön dokumentaation, konfiguraatiot ja ylläpito-ohjeet. Ympäristö rakennettiin osana opinnäytetyötä, jonka tavoitteena oli siirtää ohjelmistokehityksen työkaluketju julkipilvestä kustannustehokkaaseen ja tietoturvalliseen Raspberry Pi 5 -pohjaiseen reunalaskentaympäristöön.

Ympäristö korvaa aiemman Hetzner Cloud -pohjaisen kehitysympäristön. Toteutuksessa painotetaan kustannustehokkuutta, datasuvereniteettia, Zero Trust -periaatetta, käyttöjärjestelmän koventamista, Docker Compose -pohjaista ylläpidettävyyttä sekä 3–2–1-varmuuskopiointikäytäntöä.

## Sisällys

- [Ympäristön tarkoitus](#ympäristön-tarkoitus)
- [Arkkitehtuuri](#arkkitehtuuri)
- [Keskeiset teknologiat](#keskeiset-teknologiat)
- [Tietoturvaperiaatteet](#tietoturvaperiaatteet)
- [Hakemistorakenne](#hakemistorakenne)
- [Ympäristön käyttö](#ympäristön-käyttö)
- [Pääsynhallinta](#pääsynhallinta)
- [Docker Compose -ylläpito](#docker-compose--ylläpito)
- [Palveluiden päivitys](#palveluiden-päivitys)
- [TLS-sertifikaatit](#tls-sertifikaatit)
- [Varmuuskopiointi](#varmuuskopiointi)
- [Palautus vikatilanteessa](#palautus-vikatilanteessa)
- [Tietoturvakovennukset](#tietoturvakovennukset)
- [Valvonta](#valvonta)
- [Yleiset vikatilanteet](#yleiset-vikatilanteet)
- [Ylläpidon tarkistuslista](#ylläpidon-tarkistuslista)

## Ympäristön tarkoitus

Ympäristön tarkoituksena on tarjota Codebased Oy:lle oma, suljettu ja ylläpidettävä kehitystyökalujen alusta, joka ei ole riippuvainen julkipilvipalveluiden hinnanmuutoksista tai julkisesta internet-altistuksesta.

Ympäristössä ajetaan seuraavia kehitystyökaluja:

| Palvelu | Tarkoitus |
|---|---|
| GitLab CE | Lähdekoodin versionhallinta ja CI/CD |
| GitLab Runner | CI/CD-putkien suorittaminen |
| SonarQube | Koodin laadun ja teknisen velan analysointi |
| PostgreSQL | SonarQuben tietokanta |
| HashiCorp Vault | Salaisuuksien ja avainten hallinta |
| NGINX | Reverse proxy ja TLS-terminointi |
| Tailscale | Zero Trust -pohjainen yksityinen verkko |
| UFW | Palomuurisääntöjen hallinta |
| Restic | Salattu paikallinen varmuuskopiointi |
| rsync | Off-site-varmuuskopioiden synkronointi |
| NUT | UPS-laitteen valvonta ja hallittu alasajo |

Passbolt- ja Certbot-kontit poistettiin migraation yhteydessä arkkitehtuurin yksinkertaistamiseksi ja Raspberry Pi 5 -alustan kuorman keventämiseksi.

## Arkkitehtuuri

Ympäristö toimii Raspberry Pi 5 -laitteella, jossa on Ubuntu Server 24.04 LTS ARM64 -käyttöjärjestelmä. Palvelut suoritetaan Docker-kontteina Docker Compose -työkalun avulla.

Ympäristö ei avaa palveluita suoraan julkiseen internetiin. Kaikki hallinta- ja palveluyhteydet kulkevat Tailscale-verkon kautta. UFW-palomuuri sallii sisään tulevan liikenteen vain Tailscalen virtuaalisen verkkokortin kautta.

Yksinkertaistettu arkkitehtuuri:

```text
Developer laptop
     |
     | Tailscale VPN / Zero Trust
     |
Raspberry Pi 5 / Ubuntu Server 24.04
     |
     |-- UFW firewall
     |-- Docker Compose
          |
          |-- nginx_lb
          |-- gitlab
          |-- gitlab_runner
          |-- sonarqube
          |-- postgres
          |-- hvault
```

## Keskeiset teknologiat

| Teknologia | Käyttötarkoitus |
|---|---|
| Raspberry Pi 5 | Fyysinen ARM64-palvelinalusta |
| Ubuntu Server 24.04 LTS | Palvelimen käyttöjärjestelmä |
| Docker | Konttien suoritusympäristö |
| Docker Compose | Palvelukokonaisuuden deklaratiivinen hallinta |
| Tailscale | Salattu yksityinen mesh-verkko |
| UFW | Host-tason palomuuri |
| NGINX | Reverse proxy |
| GitLab CE | Versionhallinta ja CI/CD |
| SonarQube | Staattinen koodianalyysi |
| HashiCorp Vault | Salaisuuksien hallinta |
| Restic | Salattu varmuuskopiointi |
| rsync | Off-site-synkronointi |
| NUT | UPS-hallinta |
| Ansible Lockdown | CIS Level 1 -kovennusten automatisointi |
| Ubuntu Security Guide | CIS-auditointi |

## Tietoturvaperiaatteet

Ympäristön tietoturva perustuu seuraaviin periaatteisiin:

1. Palvelinta ei altisteta suoraan julkiseen internetiin.
2. Kaikki hallinta tapahtuu Tailscale-verkon kautta.
3. UFW estää oletuksena kaiken sisään tulevan liikenteen.
4. SSH-yhteydet sallitaan vain Tailscale-verkon kautta.
5. SSH-salasanakirjautuminen poistetaan käytöstä tuotantokovennuksen jälkeen.
6. Käyttöjärjestelmä kovennetaan CIS Level 1 -periaatteiden mukaisesti.
7. Tarpeettomat palvelut ja paketit poistetaan.
8. Automaattiset tietoturvapäivitykset otetaan käyttöön.
9. Varmuuskopiot salataan ennen paikallista ja off-site-tallennusta.
10. Salaisuuksia, avaimia, salasanoja tai `.env`-tiedostoja ei tallenneta julkiseen Git-repositorioon.

## Hakemistorakenne

Repositorion suositeltu rakenne:

```text
.
├── README.md
├── docker/
│   ├── docker-compose.yml
│   ├── gitlab/
│   │   └── gitlab.yml
│   ├── gitlab-runner/
│   │   └── config.toml.example
│   ├── sonarqube/
│   ├── postgres/
│   ├── hashicorp-vault/
│   │   ├── vault.yml
│   │   └── vault.hcl.example
│   └── nginx/
│       ├── nginx.yml
│       └── nginx.conf
├── raspberry-pi-5/
│   ├── crontab
│   ├── 99-sonarqube.conf
│   ├── backup-local.sh
│   ├── backup-offsite.sh
│   └── restore-example.sh
├── tailscale/
│   ├── acl-example.json
│   └── crontab
├── ansible/
│   └── ansible-lockdown.yml
├── docs/
│   ├── migration.md
│   ├── backup-and-restore.md
│   ├── hardening.md
│   └── troubleshooting.md
└── benchmarks/
    └── README.md
```

Todellinen rakenne voi poiketa yllä olevasta, mutta ylläpitoperiaate on sama: Docker-, Tailscale-, varmuuskopiointi-, kovennus- ja dokumentaatiotiedostot pidetään versionhallinnassa erillään salaisuuksista.

## Ympäristön käyttö

### Kirjautuminen palvelimelle

Palvelimelle kirjaudutaan vain Tailscale-verkon kautta.

```bash
ssh <käyttäjätunnus>@codebased-edge
```

Vaihtoehtoisesti voidaan käyttää Tailscalen antamaa yksityistä IP-osoitetta:

```bash
ssh <käyttäjätunnus>@<tailscale-ip>
```

Tarkista palvelimen Tailscale-tila:

```bash
tailscale status
```

Tarkista palvelimen IP-osoitteet:

```bash
ip addr
```

Tarkista järjestelmän perustiedot:

```bash
hostnamectl
uname -a
uptime
df -h
free -h
```

## Pääsynhallinta

### Uuden käyttäjän lisääminen

Uuden kehittäjän pääsy edellyttää kahta vaihetta:

1. Käyttäjän laite lisätään Codebased Oy:n Tailscale-ympäristöön.
2. Palvelimelle luodaan henkilökohtainen Linux-käyttäjätili.

Luo uusi käyttäjä:

```bash
sudo adduser <käyttäjätunnus>
```

Suositeltu käyttäjätunnusmuoto:

```text
etunimen ensimmäinen kirjain + sukunimi
```

Esimerkki:

```text
llimnell
```

Luo turvallinen väliaikainen salasana:

```bash
pwgen -s 12 1
```

Pakota käyttäjä vaihtamaan salasana ensimmäisellä kirjautumiskerralla:

```bash
sudo chage -d 0 <käyttäjätunnus>
```

### Käyttäjän poistaminen

Poista käyttäjä:

```bash
sudo deluser <käyttäjätunnus>
```

Poista käyttäjä ja kotihakemisto:

```bash
sudo deluser --remove-home <käyttäjätunnus>
```

Poista käyttäjän laite myös Tailscalen hallintapaneelista tai ACL-säännöistä.

## Docker Compose -ylläpito

Siirry Docker Compose -hakemistoon:

```bash
cd /path/to/repository/docker
```

Tarkista konttien tila:

```bash
docker compose ps
```

Käynnistä kaikki palvelut:

```bash
docker compose up -d
```

Pysäytä kaikki palvelut:

```bash
docker compose down
```

Käynnistä yksittäinen palvelu uudelleen:

```bash
docker compose restart <palvelun_nimi>
```

Esimerkki:

```bash
docker compose restart gitlab
```

Näytä kaikkien palveluiden lokit:

```bash
docker compose logs -f
```

Näytä yksittäisen palvelun lokit:

```bash
docker compose logs -f gitlab
docker compose logs -f gitlab_runner
docker compose logs -f sonarqube
docker compose logs -f hvault
docker compose logs -f nginx_lb
```

Tarkista konttien resurssinkäyttö:

```bash
docker stats
```

Tarkista Dockerin levytilankäyttö:

```bash
docker system df
```

Poista käyttämättömät imaget, verkot ja build-cache:

```bash
docker system prune
```

Älä suorita `docker volume prune` -komentoa tuotannossa ilman erillistä varmistusta, koska se voi poistaa pysyvää palveludataa.

## Palveluiden päivitys

Palveluiden päivitys tehdään muuttamalla kyseisen palvelun Docker image -versio konfiguraatiotiedostossa. Älä käytä sokkona `latest`-tagia tuotannossa.

Yleinen päivitysprosessi:

1. Lue päivitettävän ohjelmiston viralliset release notes -tiedot.
2. Tarkista ARM64-yhteensopivuus.
3. Tarkista mahdollinen migraatiopolku.
4. Ota varmuuskopio.
5. Muuta image-versio Docker Compose -tiedostoon.
6. Käynnistä palvelu uudelleen.
7. Tarkista lokit.
8. Testaa käyttöliittymä ja kirjautuminen.
9. Commitoi muutos Git-repositorioon.

Esimerkki:

```bash
cd /path/to/repository/docker
docker compose pull gitlab
docker compose up -d gitlab
docker compose logs -f gitlab
```

### GitLab-päivitykset

GitLabin päivityksissä on noudatettava GitLabin virallista päivityspolkua. Suuria versioloikkia ei pidä tehdä suoraan, koska tietokantamigraatiot voivat epäonnistua.

Tarkista GitLabin tila kontin sisältä:

```bash
docker exec -it gitlab gitlab-rake gitlab:check SANITIZE=true
```

Tarkista GitLabin salaisuudet:

```bash
docker exec -it gitlab gitlab-rake gitlab:doctor:secrets
```

### SonarQube-päivitykset

Ennen SonarQuben päivitystä tarkista:

- Java-vaatimukset
- PostgreSQL-yhteensopivuus
- Plugin-yhteensopivuus
- ARM64-image-tuki
- SonarQuben upgrade notes

Tarkista SonarQuben lokit:

```bash
docker compose logs -f sonarqube
```

Tarkista PostgreSQL-kontti:

```bash
docker compose logs -f postgres
```

### HashiCorp Vault -päivitykset

Ennen Vaultin päivitystä varmista, että:

- Vaultin data on varmuuskopioitu.
- Unseal-avaimet ovat turvallisesti saatavilla.
- OIDC-asetukset ja redirect URI -osoitteet on dokumentoitu.
- Vaultin konfiguraatiotiedosto ei sisällä salaisuuksia Git-repositoriossa.

Tarkista Vaultin tila:

```bash
docker exec -it hvault vault status
```

## TLS-sertifikaatit

Ympäristössä ei käytetä erillistä Certbot-konttia, vaan TLS-sertifikaatit tuotetaan Tailscalen kautta. Sertifikaatit liitetään NGINX-konttiin Docker Compose -volyymin avulla.

Sertifikaattien uusiminen voidaan automatisoida cron-ajastuksella.

Tarkista nykyiset cron-ajastukset:

```bash
crontab -l
```

Esimerkki sertifikaatin manuaalisesta luonnista tai uusimisesta:

```bash
sudo tailscale cert <palvelunimi>.<tailnet>.ts.net
```

Tarkista NGINX-konfiguraatio kontin sisällä:

```bash
docker exec -it nginx_lb nginx -t
```

Käynnistä NGINX uudelleen:

```bash
docker compose restart nginx_lb
```

## Varmuuskopiointi

Ympäristössä käytetään 3–2–1-varmuuskopiointimallia:

1. Aktiivinen data Raspberry Pi 5 -palvelimella.
2. Paikallinen salattu kopio USB-muistitikulla.
3. Off-site-kopio Hetzner Storage Box -palvelussa.

Varmuuskopiointi perustuu Resticiin ja rsynciin.

### Paikallinen varmuuskopiointi

Paikallinen varmuuskopiointi tehdään Resticillä USB-muistitikulle. USB-muistitikku liitetään esimerkiksi hakemistoon:

```text
/mnt/usb
```

Tarkista, että USB-muistitikku on liitetty:

```bash
mount | grep /mnt/usb
df -h /mnt/usb
```

Tarkista Restic-repositorio:

```bash
restic -r /mnt/usb/restic-repo check
```

Listaa varmuuskopiot:

```bash
restic -r /mnt/usb/restic-repo snapshots
```

Aja paikallinen varmuuskopio manuaalisesti:

```bash
sudo /path/to/repository/raspberry-pi-5/backup-local.sh
```

### Off-site-varmuuskopiointi

Off-site-varmuuskopiointi synkronoi paikallisen salatun Restic-repositorion Hetzner Storage Boxiin rsyncillä SSH-yhteyden yli.

Aja off-site-synkronointi manuaalisesti:

```bash
sudo /path/to/repository/raspberry-pi-5/backup-offsite.sh
```

Tarkista rsync-yhteys:

```bash
ssh <storagebox-user>@<storagebox-host>
```

Tarkista ajastukset:

```bash
crontab -l
```

Suositeltu ajoitus:

```text
02:00 paikallinen Restic-varmuuskopio
03:30 off-site rsync-synkronointi
```

Näin paikallinen varmuuskopiointi ehtii valmistua ennen off-site-siirtoa.

### Varmuuskopioiden säilytys

Suositeltu säilytyskäytäntö:

```text
7 päivittäistä kopiota
4 viikoittaista kopiota
```

Esimerkki Restic-komennosta:

```bash
restic -r /mnt/usb/restic-repo forget --keep-daily 7 --keep-weekly 4 --prune
```

## Palautus vikatilanteessa

### Yksittäisen tiedoston palautus

Listaa snapshotit:

```bash
restic -r /mnt/usb/restic-repo snapshots
```

Palauta yksittäinen snapshot väliaikaiseen hakemistoon:

```bash
mkdir -p /tmp/restore-test
restic -r /mnt/usb/restic-repo restore <snapshot-id> --target /tmp/restore-test
```

Tarkista palautettu sisältö:

```bash
ls -lah /tmp/restore-test
```

Älä palauta suoraan tuotantohakemistoon ennen kuin palautettu data on tarkistettu.

### Yksittäisen kontin palautus

Yleinen palautusprosessi:

1. Pysäytä kyseinen kontti.
2. Ota nykyisestä tilanteesta hätäkopio.
3. Palauta tarvittava data Restic-varmuuskopiosta väliaikaiseen hakemistoon.
4. Korvaa vioittunut data palautetulla versiolla.
5. Käynnistä kontti.
6. Tarkista lokit ja käyttöliittymä.

Esimerkki:

```bash
cd /path/to/repository/docker
docker compose stop <palvelu>

mkdir -p /tmp/restore-test
restic -r /mnt/usb/restic-repo restore <snapshot-id> --target /tmp/restore-test

# Tarkista palautettu data ennen kopiointia tuotantoon.
ls -lah /tmp/restore-test

docker compose up -d <palvelu>
docker compose logs -f <palvelu>
```

### Koko ympäristön palautus uudelle laitteelle

Koko ympäristön palautus tehdään näin:

1. Asenna Ubuntu Server 24.04 LTS ARM64 uudelle Raspberry Pi 5 -laitteelle.
2. Asenna Docker ja Docker Compose.
3. Asenna Tailscale ja liitä laite Codebased Oy:n tailnetiin.
4. Konfiguroi UFW sallimaan vain Tailscale-liikenne.
5. Kloonaa tämä repositorio.
6. Palauta Docker-volyymit tai `/var/lib/docker` varmuuskopiosta.
7. Tarkista tiedosto-oikeudet.
8. Käynnistä Docker Compose -ympäristö.
9. Tarkista GitLab, SonarQube, Vault ja NGINX.
10. Testaa kirjautuminen ja CI/CD-putki.
11. Tarkista varmuuskopioinnin ajastukset.

## Tietoturvakovennukset

Käyttöjärjestelmä kovennetaan CIS Level 1 -periaatteiden mukaisesti. Kovennuksissa hyödynnetään Ansible Lockdown -roolia ja Ubuntu Security Guide -auditointia.

### Tärkeimmät kovennukset

- root-kirjautuminen pois käytöstä
- SSH-salasanakirjautuminen pois käytöstä
- SSH MaxAuthTries -rajoitus
- automaattiset tietoturvapäivitykset
- auditd ja rsyslog käytössä
- tarpeettomien palveluiden poisto
- tiedosto-oikeuksien tiukentaminen
- UFW oletuksena `deny incoming`
- palvelut saatavilla vain Tailscale-verkon kautta
- julkisia portteja ei avata internetiin

### UFW-tilan tarkistus

```bash
sudo ufw status verbose
```

Odotettu periaate:

```text
Default: deny incoming
Default: allow outgoing
Incoming traffic allowed only through tailscale0
```

### SSH-asetusten tarkistus

```bash
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|maxauthtries'
```

Odotettu periaate:

```text
permitrootlogin no
passwordauthentication no
maxauthtries 3
```

### USG-auditointi

Aja CIS-auditointi:

```bash
sudo usg audit cis_level1_server
```

Jos käytössä on räätälöity tailoring-tiedosto:

```bash
sudo usg audit --tailoring-file tailor.xml
```

Auditointiraportit tulee säilyttää dokumentaation mukana, jotta poikkeamat voidaan perustella myöhemmin.

## Valvonta

Ympäristön resurssien valvontaan voidaan käyttää Netdataa.

Tarkista Netdatan tila:

```bash
systemctl status netdata
```

Netdatan käyttöliittymään päästään vain sallitusta verkosta, esimerkiksi Tailscalen kautta:

```text
http://<tailscale-ip>:19999
```

Seuraa erityisesti:

- CPU-käyttö
- RAM-käyttö
- levy-I/O
- levytilan käyttö
- konttien resurssinkäyttö
- verkon liikenne
- lämpötila
- UPS-tila

Tarkista Raspberry Pi 5:n lämpötila:

```bash
vcgencmd measure_temp
```

Jos `vcgencmd` ei ole käytettävissä Ubuntu Serverissä, lämpötila voidaan tarkistaa myös järjestelmän thermal zone -tiedoista:

```bash
cat /sys/class/thermal/thermal_zone0/temp
```

Arvo ilmoitetaan yleensä milliasteina. Esimerkiksi `52000` tarkoittaa noin 52 °C.

## UPS ja virransyöttö

Ympäristö käyttää APC Back-UPS -laitetta suojaamaan palvelinta lyhyiltä sähkökatkoilta. NUT-palvelu huolehtii UPS-laitteen valvonnasta ja hallitusta alasajosta pidemmissä sähkökatkoissa.

Tarkista NUT-palveluiden tila:

```bash
systemctl status nut-server
systemctl status nut-monitor
```

Tarkista UPS-laitteen tila:

```bash
upsc <ups-nimi>
```

Esimerkkejä seurattavista arvoista:

```text
battery.charge
battery.runtime
ups.status
input.voltage
```

## Yleiset vikatilanteet

### Kontti ei käynnisty

Tarkista lokit:

```bash
docker compose logs -f <palvelu>
```

Tarkista, onko portti jo käytössä:

```bash
sudo ss -tulpn
```

Tarkista levytila:

```bash
df -h
docker system df
```

Tarkista muisti:

```bash
free -h
```

### GitLab on hidas

Tarkista resurssinkäyttö:

```bash
docker stats
```

Tarkista GitLabin tila:

```bash
docker exec -it gitlab gitlab-rake gitlab:check SANITIZE=true
```

Tarkista lokit:

```bash
docker compose logs -f gitlab
```

### GitLab Runner ei saa yhteyttä GitLabiin

Tarkista GitLab Runnerin konfiguraatio:

```bash
docker exec -it gitlab_runner cat /etc/gitlab-runner/config.toml
```

Tarkista, käyttääkö Runner sisäistä Docker-verkon osoitetta silloin, kun Tailscale-osoite ei toimi kontin sisältä.

Käynnistä Runner uudelleen:

```bash
docker compose restart gitlab_runner
```

### SonarQube ei käynnisty

Tarkista SonarQuben vaatimat kernel-parametrit:

```bash
sysctl vm.max_map_count
sysctl fs.file-max
```

Tarkista pysyvä konfiguraatio:

```bash
cat /etc/sysctl.d/99-sonarqube.conf
```

Lataa sysctl-asetukset uudelleen:

```bash
sudo sysctl --system
```

Tarkista SonarQuben ja PostgreSQL:n lokit:

```bash
docker compose logs -f sonarqube
docker compose logs -f postgres
```

### Vault on sealed-tilassa

Tarkista tila:

```bash
docker exec -it hvault vault status
```

Avaa Vault organisaation hyväksytyllä unseal-prosessilla.

Älä tallenna unseal-avaimia tähän repositorioon.

### NGINX ei välitä liikennettä oikein

Tarkista NGINX-konfiguraatio:

```bash
docker exec -it nginx_lb nginx -t
```

Tarkista lokit:

```bash
docker compose logs -f nginx_lb
```

Tarkista sertifikaatit:

```bash
ls -lah /path/to/certs
```

Käynnistä NGINX uudelleen:

```bash
docker compose restart nginx_lb
```

### Tailscale-yhteys ei toimi

Tarkista Tailscale-tila:

```bash
tailscale status
```

Tarkista IP:

```bash
tailscale ip
```

Tarkista UFW:

```bash
sudo ufw status verbose
```

Käynnistä Tailscale uudelleen:

```bash
sudo systemctl restart tailscaled
```

Kirjaudu tarvittaessa uudelleen:

```bash
sudo tailscale up
```

## Ylläpidon tarkistuslista

### Päivittäin

- Tarkista palveluiden saatavuus.
- Tarkista, että varmuuskopiointi on onnistunut.
- Tarkista kriittiset hälytykset tai poikkeavat lokit.
- Tarkista levytila, jos ympäristössä on tehty suuria muutoksia.

### Viikoittain

- Tarkista Docker-konttien tila.
- Tarkista Netdatan resurssikuvaajat.
- Tarkista Restic snapshotit.
- Tarkista off-site-varmuuskopioinnin onnistuminen.
- Tarkista UPS:n tila.
- Tarkista, ettei levytila ole kasvamassa hallitsemattomasti.

### Kuukausittain

- Tarkista käyttöjärjestelmäpäivitykset.
- Tarkista Docker image -päivitykset.
- Tarkista GitLabin, SonarQuben ja Vaultin release notes -tiedot.
- Testaa yksittäisen tiedoston palautus varmuuskopiosta.
- Tarkista Tailscale ACL -säännöt.
- Poista tarpeettomat käyttäjät ja laitteet.
- Tarkista USG/CIS-poikkeamat tarvittaessa.

### Ennen merkittäviä muutoksia

- Ota varmuuskopio.
- Tarkista, että off-site-kopio on ajan tasalla.
- Tee muutos ensin konfiguraatiotiedostoon.
- Commitoi muutos Git-repositorioon.
- Päivitä palvelu hallitusti.
- Tarkista lokit.
- Testaa käyttäjän näkökulmasta.
- Dokumentoi muutos.

## Tärkeät säännöt

- Älä avaa palveluita suoraan julkiseen internetiin.
- Älä commitoi salasanoja, avaimia, tokeneita tai `.env`-tiedostoja.
- Älä käytä `latest`-tageja tuotantopalveluissa.
- Älä aja `docker volume prune` -komentoa ilman varmistusta.
- Älä muuta UFW-sääntöjä ilman, että Tailscale-pääsy säilyy.
- Älä tee GitLabin suuria versioloikkia ilman virallisen päivityspolun tarkistamista.
- Älä palauta varmuuskopiota suoraan tuotantoon ennen testipalautusta.
- Dokumentoi kaikki pysyvät muutokset repositorioon.

## Hyödyllisiä komentoja

```bash
# Palvelimen perustila
uptime
df -h
free -h
hostnamectl

# Docker
docker compose ps
docker compose logs -f
docker stats
docker system df

# Tailscale
tailscale status
tailscale ip

# UFW
sudo ufw status verbose

# Restic
restic -r /mnt/usb/restic-repo snapshots
restic -r /mnt/usb/restic-repo check

# NUT / UPS
upsc <ups-nimi>

# Netdata
systemctl status netdata
```

## Vastuut

| Rooli | Vastuu |
|---|---|
| Codebased Oy | Ympäristön omistajuus ja jatkokäyttö |
| Pääkäyttäjä | Käyttäjähallinta, Tailscale ACL -säännöt ja operatiivinen ylläpito |
| Kehittäjät | Palveluiden käyttö ohjeiden mukaisesti |
| Opinnäytetyön tekijä | Alkuperäinen toteutus, dokumentointi ja luovutus |

## Lisenssi ja käyttöoikeudet

Tämä repositorio sisältää Codebased Oy:lle toteutetun opinnäytetyön teknisen tuotoksen. Repositorion sisältö on tarkoitettu Codebased Oy:n sisäiseen käyttöön, ellei erikseen toisin sovita.

Kolmansien osapuolten ohjelmistoihin sovelletaan niiden omia lisenssiehtoja.

## Yhteenveto

Tämä ympäristö osoittaa, että pienyrityksen ohjelmistokehityksen keskeisiä työkaluja voidaan ajaa kustannustehokkaasti ja tietoturvallisesti omassa ARM64-pohjaisessa reunalaskentaympäristössä. Raspberry Pi 5 ei korvaa suurta pilvi-instanssia raakasuorituskyvyssä, mutta se tarjoaa riittävän suorituskyvyn Codebased Oy:n nykyiseen käyttötapaukseen, kun ympäristö suunnitellaan, kovennetaan, dokumentoidaan ja varmuuskopioidaan huolellisesti.
