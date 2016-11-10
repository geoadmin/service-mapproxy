services:
  # comment out unneeded services
  demo:
  kml:
  tms:
  wmts:
     restful: true
     kvp: false
     restful_template: /1.0.0/{Layer}/default/{TileMatrixSet}/{TileMatrix}/{TileCol}/{TileRow}.{Format}

  wms:
    srs: ['EPSG:4326', 'CRS:84', 'EPSG:21781', 'EPSG:4258', 'EPSG:3857', 'EPSG:2056']
    image_formats: ['image/jpeg', 'image/png']
    md:
      # metadata used in capabilities documents
      title: GeoAdmin MapProxy WMS
      abstract: GeoAdmin geodata
      online_resource: http://api3.geo.admin.ch/mapproxy/service?
      contact:
        person: webgis@swisstopo.ch
        organization: Bundesamt für Landestopografie swisstopo
        address: Seftigenstrasse 264
        city: Wabern
        postcode: 3084
        country: Schweiz
        phone: +41 (0)31 / 963 21 11
        fax: +41 (0)31 / 963 24
        email: webgis@swisstopo.ch
      access_constraints: 'License'
      fees: 'This service cant be used without permission'

layers:
  - name: osm
    title: OpenStreetMap
    sources: [osm_cache]
  - name: "ch.kantone.cadastralwebmap-farbe_current_epsg_21781"
    title: "CadastralWebMap (Current, 21781)"
    sources:
      - ch.kantone.cadastralwebmap-farbe_epsg_21781_cache_out
  - name: "ch.kantone.cadastralwebmap-farbe_current_epsg_2056"
    title: "CadastralWebMap (Current, 2056)"
    sources:
      - ch.kantone.cadastralwebmap-farbe_epsg_2056_cache_out
  - name: "ch.kantone.cadastralwebmap-farbe_current_epsg_4258"
    title: "CadastralWebMap (Current, 4258)"
    sources:
      - ch.kantone.cadastralwebmap-farbe_epsg_4258_cache_out
  - name: "ch.kantone.cadastralwebmap-farbe_current_epsg_3857"
    title: "CadastralWebMap (Current, 3857)"
    sources:
      - ch.kantone.cadastralwebmap-farbe_epsg_3857_cache_out
  - name: "ch.kantone.cadastralwebmap-farbe_current_epsg_4326"
    title: "CadastralWebMap (Current, 4356)"
    sources:
      - ch.kantone.cadastralwebmap-farbe_epsg_4326_cache_out
  - name: ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_epsg_4326
    title: SwissTLM3D Color - 3D edition (20140401)
    sources:
      - ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_epsg_4326_cache_out

  - name: ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_epsg_4326
    title: SwissTLM3D Color - 3D edition (20140401)
    sources:
      - ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_epsg_4326_cache_out
  - name: ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_epsg_4326
    title: SwissTLM3D Shades of Grey - 3D edition (20140401)
    sources:
      - ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_epsg_4326_cache_out

sources:
  osm_tms:
    type: tile
    grid: global_mercator_osm
    url: http://c.tile.openstreetmap.org/%(tms_path)s.png
    coverage:
      bbox: [420000,30000,900000,350000]
      bbox_srs: EPSG:21781
  ch.kantone.cadastralwebmap-farbe_wms_source:
    type: wms
    wms_opts:
      version: 1.1.1
    supported_srs: ['EPSG:21781']
    req:
      url: http://wms.cadastralwebmap.ch/WMS
      layers: cm_wms
    coverage:
      bbox:
      - 0
      - 40
      - 20
      - 50
      bbox_srs: EPSG:4326
  ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_source:
    coverage:
      bbox:
      - 0
      - 40
      - 20
      - 50
      bbox_srs: EPSG:4326
    grid: epsg_4326
    http:
      headers:
        Referer: http://mapproxy.geo.admin.ch
    on_error:
      204:
        cache: true
        response: transparent
    transparent: true
    type: tile
    url: http://internal-vpc-lb-internal-wmts-infra-1291171036.eu-west-1.elb.amazonaws.com/1.0.0/ch.swisstopo.swisstlm3d-karte-farbe.3d/default/20150401/4326/%(z)d/%(y)d/%(x)d.%(format)s
  ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_source:
    coverage:
      bbox:
      - 0
      - 40
      - 20
      - 50
      bbox_srs: EPSG:4326
    grid: epsg_4326
    http:
      headers:
        Referer: http://mapproxy.geo.admin.ch
    on_error:
      204:
        cache: true
        response: transparent
    transparent: true
    type: tile
    url: http://internal-vpc-lb-internal-wmts-infra-1291171036.eu-west-1.elb.amazonaws.com/1.0.0/ch.swisstopo.swisstlm3d-karte-grau.3d/default/20150401/4326/%(z)d/%(y)d/%(x)d.%(format)s

caches:
  ch.kantone.cadastralwebmap-farbe_cache:
    disable_storage: true
    format: image/png
    grids:
    - epsg_21781
    sources:
    - ch.kantone.cadastralwebmap-farbe_wms_source
  ch.kantone.cadastralwebmap-farbe_epsg_21781_cache_out:
     disable_storage: true
     format: image/png
     grids:
     - epsg_21781
     meta_buffer: 0
     meta_size:
     - 2
     - 2
     sources:
     - ch.kantone.cadastralwebmap-farbe_cache
  ch.kantone.cadastralwebmap-farbe_epsg_2056_cache_out:
     disable_storage: true
     format: image/png
     grids:
     - epsg_2056
     meta_buffer: 0
     meta_size:
     - 2
     - 2
     sources:
     - ch.kantone.cadastralwebmap-farbe_cache
  ch.kantone.cadastralwebmap-farbe_epsg_3857_cache_out:
     disable_storage: true
     format: image/png
     grids:
     - epsg_3857
     meta_buffer: 0
     meta_size:
     - 2
     - 2
     sources:
     - ch.kantone.cadastralwebmap-farbe_cache
  ch.kantone.cadastralwebmap-farbe_epsg_4258_cache_out:
     disable_storage: true
     format: image/png
     grids:
     - epsg_4258
     meta_buffer: 0
     meta_size:
     - 2
     - 2
     sources:
     - ch.kantone.cadastralwebmap-farbe_cache
  ch.kantone.cadastralwebmap-farbe_epsg_4326_cache_out:
     disable_storage: true
     format: image/png
     grids:
     - epsg_4326
     meta_buffer: 0
     meta_size:
     - 2
     - 2
     sources:
     - ch.kantone.cadastralwebmap-farbe_cache
  osm_cache:
    grids: [global_mercator_osm]
    sources: [osm_tms]
    disable_storage: true
    concurrent_tile_creators: 4
    watermark:
      text: '@ OpenStreetMap contributors'
      font_size: 14
      opacity: 100
      color: [0,0,0]
  ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_cache:
    disable_storage: true
    format: image/jpeg
    grids:
    - epsg_4326
    sources:
    - ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_source
  ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_epsg_4326_cache_out:
     disable_storage: true
     format: image/jpeg
     grids:
     - epsg_4326
     meta_buffer: 0
     meta_size:
     - 1
     - 1
     sources:
     - ch.swisstopo.swisstlm3d-karte-farbe.3d_20150401_cache

  ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_cache:
    disable_storage: true
    format: image/jpeg
    grids:
    - epsg_4326
    sources:
    - ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_source
  ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_epsg_4326_cache_out:
     disable_storage: true
     format: image/jpeg
     grids:
     - epsg_4326
     meta_buffer: 0
     meta_size:
     - 1
     - 1
     sources:
     - ch.swisstopo.swisstlm3d-karte-grau.3d_20150401_cache




grids:
  epsg_21781:
    res: [4000,3750,3500,3250,3000,2750,2500,2250,2000,1750,1500,1250,1000,750,650,500,250,100,50,20,10,5,2.5,2,1.5,1,0.5,0.25,0.1]
    bbox: [420000,30000,900000,350000]
    bbox_srs: EPSG:21781
    srs: EPSG:21781
    origin: nw
    stretch_factor: 1.0
  swisstopo-swissimage:
    res: [4000,3750,3500,3250,3000,2750,2500,2250,2000,1750,1500,1250,1000,750,650,500,250,100,50,20,10,5,2.5,2,1.5,1,0.5,0.25]
    bbox: [420000,30000,900000,350000]
    bbox_srs: EPSG:21781
    srs: EPSG:21781
    origin: nw
    stretch_factor: 1.0
  swisstopo-pixelkarte:
    res: [4000,3750,3500,3250,3000,2750,2500,2250,2000,1750,1500,1250,1000,750,650,500,250,100,50,20,10,5,2.5,2,1.5,1,0.5]
    threshold_res: [900,700,400,200,90,40,15]
    bbox: [420000,30000,900000,350000]
    bbox_srs: EPSG:21781
    srs: EPSG:21781
    origin: nw
    stretch_factor: 1.0
  global_mercator_osm:
    base: GLOBAL_MERCATOR
    num_levels: 18
    origin: nw
  epsg_3857:
    base: GLOBAL_MERCATOR
    num_levels: 20
    origin: nw
  #lowres_etrs89:
  epsg_4258:
    base: 'GLOBAL_GEODETIC'
    srs: EPSG:4258
    res: [0.7031250000000000000000,0.3515625000000000000000, 0.1757812500000000000000, 0.0878906250000000000000,0.0439453125000000000000, 0.0219726562500000000000, 0.0109863281250000000000, 0.0054931640625000000000, 0.0027465820312500000000, 0.0013732910156250000000, 0.0006866455078125000000, 0.0003433227539062500000, 0.0001716613769531250000, 0.0000858306884765625000, 0.0000429153442382812000, 0.0000214576721191406000, 0.0000107288360595703000, 0.0000053644180297851600, 0.0000026822090148925800]
    bbox: [-180.0,-90, 180.0, 90.0]
    bbox_srs: EPSG:4326
    origin: nw
    stretch_factor: 1.0
  #lowres_wgs84:
  epsg_4326:
    base: 'GLOBAL_GEODETIC'
    srs: EPSG:4326
    res: [0.7031250000000000000000,0.3515625000000000000000, 0.1757812500000000000000, 0.0878906250000000000000,0.0439453125000000000000, 0.0219726562500000000000, 0.0109863281250000000000, 0.0054931640625000000000, 0.0027465820312500000000, 0.0013732910156250000000, 0.0006866455078125000000, 0.0003433227539062500000, 0.0001716613769531250000, 0.0000858306884765625000, 0.0000429153442382812000, 0.0000214576721191406000, 0.0000107288360595703000, 0.0000053644180297851600, 0.0000026822090148925800, 6.70552253723145e-7, 3.352761268615725e-7, 1.6763806343078624e-7, 8.381903171539312e-8, 4.190951585769656e-8]
    bbox: [-180.0,-90, 180.0, 90.0]
    bbox_srs: EPSG:4326
    origin: nw
    stretch_factor: 1.0
  #lowres_lv95:
  epsg_2056:
    res: [4000,3750,3500,3250,3000,2750,2500,2250,2000,1750,1500,1250,1000,750,650,500,250,100,50,20,10,5,2.5,2,1.5,1,0.5,0.25,0.1]
    threshold_res: [900,700,400,200,90,40,15,7.5,3,1.8,1.3,0.75,0.4,0.15]
    # Let Mapproxy do the bbox calculation
    bbox: [420000.0, 030000.0, 900000.0, 350000.0]
    bbox_srs: EPSG:21781
    srs: EPSG:2056
    origin: nw
    stretch_factor: 1.05

globals:
  cache:
    # use parallel requests to the WMTS sources
    concurrent_tile_creators: 32
  image:
      resampling_method: bicubic
      # for 24bits PNG
      paletted: false
      formats:
         image/png:
             mode: RGBA 
             transparent: true
         image/jpeg:
             mode: RGB 
             encoding_options:
                 jpeg_quality: 88

  srs:
    # Custom proj_lib definitions
    proj_data_dir: ./proj_data
    # for North/East ordering (default for geographic)
    axis_order_ne:  ['EPSG:4326', 'EPSG:4258', 'EPSG:3857']
    # for East/North ordering (default for projected)
    axis_order_en: ['EPSG:21781', 'EPSG:2056'] 

