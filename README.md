# osmreplicationtrees

From a daily updated `.osm.pbf` file (e.g. a planet file), keep up-to-date child areas

* `.osm.pbf` files
* daily replication trees suitable for Osmosis updates

It could be useful for example

* if you need a daily `.osc.gz` file on a custom area which is not already provided by somebody else
* you don't want to rely on an OSM data provider for your change files except Planet OSM servers

What's called a daily replication tree ? It looks like that: [Planet OSM daily replication tree root](https://planet.osm.org/replication/day/).

## More details

Let's take an example: with an available daily updated `planet-latest.osm.pbf` as a root parent area PBF file, you can daily update:

* `mycountry-latest.osm.pbf` file
* `mycountry-latest/replication/day/` replication tree

`osmreplicationtrees` can be use recursively. For instance, from a parent root area, your child areas could be `country1` and `country2`, and `country2` can be the parent of a `country2-subregion` child area, and so on).

For sure, your parent root area must geographically comprises all its comming child areas...

## Acronyms

Below acronyms are used for convenience in this repository

* `RPA`: `Root Parent Area`
* `PA`: `Parent Area`
* `CA`: `Child Area`
* `RT`: `Replication Tree`

## How it works?

In summary, the procedure is (on a daily basis):

* update the Root Parent Area PBF file using Osmosis, Osmium and an existing replication tree (e.g. at Planet OSM, GeoFabrik...)
* for each child area
  * extract corresponding PBF files from its Parent Area PBF file using Osmium and a `.poly` file
  * compare this new PBF file to the last one with Osmium to produce a corresponding `.osc.gz` change file
  * update the replication tree

## Software requirements

* GNU/Linux Debian based system (tested with Debian 9 and Ubuntu 18.04).
* docker-ce version >=19 (tested with docker-ce 19.03.5), [official install doc](https://docs.docker.com/install/linux/docker-ce/debian/)

## Get source code

* clone this repo
* go to root directory

```bash
cd osmreplicationtrees/
```

## Adapt configuration

Two default config files are provided under `./conf/` directory. You can use one of them for testing purposes. Just rename one of them to `config`. For instance, to test quickly, using less than 1 GB if disk space, just run:

```bash
cp ./conf/config_midi-pyrenees_toulouse_toulouse-centreville ./conf/config
```

To custom configuration, have a look at `Configuration customisation` section below.

## Usage

```bash
# read configuration
. ./conf/config
# run this script until there is no error. It will check if all requirements are fullfilled and tell you what to do if necessary
bash ./check_requirements.sh
# build docker
sudo docker build --tag $DOCKER_BUILD_TAG docker
# deploy trees
bash ./run_docker_and_deploy_trees.sh
# keep everything up-to-date
sudo bash -c "cat <<EOF > /etc/cron.d/keepup_docker-$DOCKER_NAME
30 0 * * * root docker exec $DOCKER_NAME bash ${DOCKERPATH_SOURCE_DIR}/scripts/keepup_trees.sh > $HOSTPATH_LOGS_DIR/keepup_trees.log 2>&1
EOF"
```

## Maintenance

### Restart from a fresh Root Parent Area PBF file

As time goes, it could be a good idea to refresh your RPA latest PBF file by downloading a fresh file from your original RPA provider. Next script handles that for you:

```bash
sudo docker exec $DOCKER_NAME \
bash ${DOCKERPATH_SOURCE_DIR}/scripts/tasks/reinit_RPA_osm_file.sh \
--osm-file-days-of-delay "${RPA_INITIAL_DAYS_OF_DELAY}"
```

### Add a new child area to a running instance

* update some config file variables
  * `CA_NAMES`: add new child area name in the list
  * `PARENTS_NAMES`, `PARENTS_DIR`, `PARENTS_STATE_FILE_DIR`: add needed information about the parent of the new child area
* add new child area `.poly` file in `./conf/poly_files` directory
* run `./check_requirements.sh` to make sure everything is OK
* it's done: the next time `keepup_trees.sh` will run, it will detect the new child area and initialize the replication tree

## Configuration customisation

### Base directory

`HOST_VOLUMES_BASE_DIR` host must have enough disk space (see `Disk space usage benchmark` below)

### RPA PBF file

A daily updated root parent area `.osm.pbf` file available on your server will be necessary.

Because it's not recommended to download it every day from a data provider (as Planet OSM, Geofabrik or another), it's better to download it once from an OSM data provider and keep it up-to-date thanks to Osmosis. Consequently your root parent area must respect two requirements:

* a corresponding `.osm.pbf` file is available somewhere (`$RPA_OSM_FILE_DOWNLOAD_URL` in `./conf/config`)
* a corresponding daily replication tree is available somewhere (`$RPA_RT_URL` in `./conf/config`)

Latest available RPA `.osm.pbf` file is not necessary up-to-date (for instance if your RPA is `planet.osm.pbf` from Planet OSM, it's updated only once per week). Be sure that `$RPA_INITIAL_DAYS_OF_DELAY` corresponds to the number of day between the latest available `state.txt` file and your `planet.osm.pbf` timestamp (add 1 day to be sure).

#### Child areas POLY file(s)

For each child area, you need a `.poly` file which is an "extraction polygon" in the "Osmosis polygon filter file format". More information at [Wiki OSM - Osmosis/Polygon Filter File Format](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format).

Each `.poly` file will be used to extract a `child_area.osm.pbf` from its parent `parent_area.osm.pbf` file.

If desired `.poly` files are available for download somewhere, you may use `$CA_POLY_FILES_DOWNLOAD_URL` config variable to provide urls. If not, the `check_requirements.sh` script will told you where to save your `.poly` files.

### Disk space usage benchmark

For one replication tree, you have to host (indicated sizes stand for `planet` as root parent area, and `france` as child area, in january 2020):

* two root parent area `.osm.pbf` files  (2*49 GB ~ 100 GB)
* at least two `child_area.osm.pbf` files (for instance 2*3.5 GB ~ 7 GB for France)
* a child area replication tree (roughly estimated at 0,04% of your `child_area.osm.pbf` size more each day, from starting day ; for instance about 500MB for 6 months for France)
