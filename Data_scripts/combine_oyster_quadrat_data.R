# this script cleans up and combines the oyster quadrat data files

# Notes:
# the data format of "Grid_data_Nov_2012_bp.csv" is closest to how we want the final data (minor changes)
# Columns: Date (m/d/y) 
#'         Month
#'         Locality (2-character code)
#'         Site (I=inshore, O=offshore, N=nearshore)
#'         Bar (numeric)
#'         Station (combined Locality, Site, Bar)
#'         Counter (initials of person counting)
#'         Quadrat_ID (unique ID that refers to a single quadrat from a single day: 
#'                      year,month,day,Station,Replicate,quadrat   e.g. 20180130_BTI1_11)
#'         Live_Dead (L/D)
#'         Size (length of oyster; count=1)
#'         Count (number of oysters)
#'         Treatment (experiment: control, control_pre, control_post, restore_pre, restore_post)
#'         
#'         
#' In creating the Quadrat_IDs, I also make a table of these IDs with location information
#' e.g. for older data (2010-2017) the sample protocol was a grid, so these quadrats have a Dist_Alng and Dist_frm column
#'      2018 quadrats were placed a random distance in a random direction from a central point


library(plyr)
library(dplyr)

# ======================================================================================================
# Functions


#' this function takes a quadrat data frame and creates Quadrat_ID numbers for each unique quadrat based on date, station, and replicate
#' 
#' 
#' @param quad_df data frame: must have Date, Station, and Replicate columns
#' @param location_columns list of column names which determine a unique quadrat (e.g. Dist_Alng,Dist_frm,Direction)
#' 
#' @return dataframe of Quadrat_ID numbers with Date, Station, Replicate
#' 
make_quadrat_id_dataframe = function(quad_df,location_columns) {
  # split Date column into month, day, year columns
  quad_df$mo = format(quad_df$Date,'%m') %>% as.numeric() %>% sprintf(fmt='%02d')
  quad_df$dy = format(quad_df$Date,'%d') %>% as.numeric() %>% sprintf(fmt='%02d')
  quad_df$yr = format(quad_df$Date,'%Y')
  
  # create location data frame
  quad_df.locations = quad_df %>% select(location_columns,Date,Station,Replicate,yr,mo,dy) %>% unique()
  # put rows in order
  quad_df.locations = quad_df.locations[with(quad_df.locations,order(yr,mo,dy,Station,Replicate)),]
  
  # make column of combinded date, location, replicate
  quad_df.locations$Replicate_chr = sprintf(quad_df.locations$Replicate,fmt='%02d')
  quad_df.locations$dateloc = paste0(quad_df.locations$yr,quad_df.locations$mo,quad_df.locations$dy,'_',quad_df.locations$Station,'_',quad_df.locations$Replicate_chr)
  
  # make quadrat column if it doesn't already exist; count number of quadrats per unique date and location
  if (!('Quadrat' %in% colnames(quad_df.locations))) {
    quad_df.locations$Quadrat=rep(NA)
    for (ID in unique(quad_df.locations$dateloc)) {
      n_ID = length(quad_df.locations[quad_df.locations$dateloc==ID,1])
      quad_df.locations$Quadrat[quad_df.locations$dateloc==ID] <- seq(n_ID) 
    }
  }
  
  # make quadrat column character, 2 digits
  quad_df.locations$quadrat_num = sprintf(quad_df.locations$Quadrat,fmt='%02d')
  
  # create Quadrat_ID: yyyymmdd_station_replicate_quadrat 
  quad_df.locations$Quadrat_ID = paste0(quad_df.locations$dateloc,'_',
                                        quad_df.locations$quadrat_num)
  
  #return just desired columns
  locations = quad_df.locations[,c('Date','Station','Quadrat_ID','Replicate',location_columns)]
  return(locations)
}

# ====================================================================================================================================

# read in data files
quad2012 = read.csv('Oyster_data/Quadrat/Grid_data_Nov_2012_bp.csv',stringsAsFactors = F,na.strings = c('',' '))
quad2013 = read.csv('Oyster_data/Quadrat/Oyster_grid_2013_2017.csv',stringsAsFactors = F)
quad2015 = read.csv('Oyster_data/Quadrat/Oyster_grid_2015.csv',stringsAsFactors = F)
quad2018 = read.csv('Oyster_data/Quadrat/OysterData_30Jan2018_Quadrat_final.csv',stringsAsFactors = F)
quad2018b = read.csv('Oyster_data/Quadrat/OysterData_16Feb2018_Quadrat_final.csv',stringsAsFactors = F)
quad2018c = read.csv('Oyster_data/Quadrat/20180302_oyster_quadrat.csv',stringsAsFactors = F)


# ---------------------------------------------------------------------------------------
# 2012 data cleaning

# format Date column
quad2012$Date = as.Date(quad2012$Date,format='%m/%d/%Y')

# create Treatment column
quad2012$Treatment = rep('control')

# create Replicate column (only used in 2013-2017)
quad2012$Replicate = rep(1)

# Quad_type column
quad2012$Quad_type = rep('SURFACE')

# Quad_area column
quad2012$Quad_area = rep(0.0625)

# put rows in order
quad2012 = quad2012[with(quad2012,order(Trip,Station,Dist_Alng,Dist_frm,Direction)),]

# create Quadrat_ID column
quad2012.locations = make_quadrat_id_dataframe(quad2012,c('Dist_Alng','Dist_frm','Direction','Quad_type','Quad_area'))

# attach Quadrat_ID to quad2012 data frame
quad2012_modified = merge(quad2012,quad2012.locations,all.x=T)

# extract out the desired columns
quad.2012 = quad2012_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]


# ----------------------------------------------------------------------------------------
# 2013 data cleaning

# create Month column
quad2013$Date = as.Date(quad2013$Date)
quad2013$Month = format(quad2013$Date,'%m') %>% as.numeric()

# convert numeric month to month name
quad2013$Month = month.name[as.numeric(quad2013$Month)]

# rename Transect column to be Replicate
colnames(quad2013)[colnames(quad2013)=='Transect'] <- 'Replicate'

# create Locality, Site, Bar columns (first 2 characters, middle n characters, and last character of Station respectively)
for (n in 1:length(quad2013$Station)) {
  quad2013$Locality[n] = substr(quad2013$Station[n],1,2)
  quad2013$Site[n] = substr(quad2013$Station[n],3, nchar(quad2013$Station[n])-1)
  quad2013$Bar[n] = substr(quad2013$Station[n], nchar(quad2013$Station[n]), nchar(quad2013$Station[n]))
}

# create Treatment column from Station and Condition info
# some notes:  all treatment is 'control' except Locality=LC Site=O -- a rock restoration experiment was done in 2013-2014
#              all sites in this file should be 'O'
#              bars 1,2,5,6 were restored with rocks, bars 3,4,7,8 were controls
#              pre/post refers to before/after rock addition (2013 is pre, 2014 is post)
quad2013$Treatment = rep(NA)
for (n in 1:length(quad2013$Station)) {
  if (quad2013$Bar[n] %in% c(1,2,5,6)) {quad2013$Treatment[n] = paste0('restore_',quad2013$Condition)}
  else if (quad2013$Bar[n] %in% c(3,4,7,8)) {quad2013$Treatment[n] = paste0('control_',quad2013$Condition)}
}

# 'restore' is not a real Site name. All the sites in this file are 'O' 
quad2013$Site = rep('O')

# Station should be combination of Locality, Site, Bar
quad2013$Station_old = quad2013$Station
quad2013$Station = paste0(quad2013$Locality,quad2013$Site,quad2013$Bar)

# needs a Direction column even though L/R info was not recorded in this epoch
quad2013$Direction = rep(NA)

# Quad_type column
quad2013$Quad_type = rep('SURFACE')

# Quad_area column
quad2013$Quad_area = rep(0.0625)

# create Quadrat_ID column
quad2013.locations = make_quadrat_id_dataframe(quad2013,c('Dist_Alng','Dist_frm','Direction','Quad_type','Quad_area'))

# attach Quadrat_ID to quad2012 data frame
quad2013_modified = merge(quad2013,quad2013.locations,all.x=T)

# select correct columns
quad.2013 = quad2013_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]


# -------------------------------------------------------------------------------------------------
# 2015 data cleaning

# create Month column
quad2015$Date = as.Date(quad2015$Date)
quad2015$Month = format(quad2015$Date,'%m') %>% as.numeric()

# convert numeric month to month name
quad2015$Month = month.name[as.numeric(quad2015$Month)]

# rename Transect column to be Replicate
colnames(quad2015)[colnames(quad2015)=='Transect'] <- 'Replicate'

# create Locality, Site, Bar columns (first 2 characters, middle n characters, and last character of Station respectively)
for (n in 1:length(quad2015$Station)) {
  quad2015$Locality[n] = substr(quad2015$Station[n],1,2)
  quad2015$Site[n] = substr(quad2015$Station[n],3, nchar(quad2015$Station[n])-1)
  quad2015$Bar[n] = substr(quad2015$Station[n], nchar(quad2015$Station[n]), nchar(quad2015$Station[n]))
}

#all Site in this file are 'O', but were entered as '0'
quad2015$Site = rep('O')

# create Treatment column
quad2015$Treatment = rep('control')

# needs a Direction column even though L/R info was not recorded in this epoch
quad2015$Direction = rep(NA)

# Quad_type column
quad2015$Quad_type = rep('SURFACE')

# Quad_area column
quad2015$Quad_area = rep(0.0625)

# create Quadrat_ID column
quad2015.locations = make_quadrat_id_dataframe(quad2015,c('Dist_Alng','Dist_frm','Direction','Quad_type','Quad_area'))

# attach Quadrat_ID to quad2015 data frame
quad2015_modified = merge(quad2015,quad2015.locations,all.x=T)

# select correct columns
quad.2015 = quad2015_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]


# --------------------------------------------------------------------------------------------------
# 2018 January data cleaning

# create Month column
quad2018$Date = as.Date(quad2018$Date,format='%m/%d/%Y')
quad2018$Month = format(quad2018$Date,'%m') %>% as.numeric()

# convert numeric month to month name
quad2018$Month = month.name[as.numeric(quad2018$Month)]

# Station should be Locality, Site, Bar
quad2018$Station_old = quad2018$Station
quad2018$Station = paste0(quad2018$Locality,quad2018$Site,quad2018$Bar)

# rename Height column to be Size (match older data)
colnames(quad2018)[colnames(quad2018)=='Height'] <- 'Size'

# need Treatment column (these are all controls)
quad2018$Treatment = rep('control')

# need Replicate column even though it's unused
quad2018$Replicate = rep(1)

# create Quadrat_ID column
quad2018.locations = make_quadrat_id_dataframe(quad2018,c('Quadrat','Quad_Lat','Quad_Long','Center_Lat','Center_Long','Rand_Coord','Rand_Dist','Quad_type','Quad_area','Quad_Depth'))

# attach Quadrat_ID to quad2018 data frame
quad2018_modified = merge(quad2018,quad2018.locations,all.x=T)

# select correct columns
quad.2018 = quad2018_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]


# --------------------------------------------------------------------------------------------------
# 2018 February data cleaning

# create Month column
quad2018b$Date = as.Date(quad2018b$Date,format='%m/%d/%Y')
quad2018b$Month = format(quad2018b$Date,'%m') %>% as.numeric()

# convert numeric month to month name
quad2018b$Month = month.name[as.numeric(quad2018b$Month)]

# Station should be Locality, Site, Bar
quad2018b$Station_old = quad2018b$Station
quad2018b$Station = paste0(quad2018b$Locality,quad2018b$Site,quad2018b$Bar)

# rename Height column to be Size (match older data)
colnames(quad2018b)[colnames(quad2018b)=='Height'] <- 'Size'

# need Treatment column (these are all controls)
quad2018b$Treatment = rep('control')

# need Replicate column even though it's unused
quad2018b$Replicate = rep(1)

# create Quadrat_ID column
quad2018b.locations = make_quadrat_id_dataframe(quad2018b,c('Quadrat','Quad_Lat','Quad_Long','Center_Lat','Center_Long','Rand_Coord','Rand_Dist','Quad_type','Quad_area','Quad_Depth'))

# attach Quadrat_ID to quad2018 data frame
quad2018b_modified = merge(quad2018b,quad2018b.locations,all.x=T)

# select correct columns
quad.2018b = quad2018b_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]

# -----------------------------------------------------------------------------------------------------------
# 2018 March data cleaning

# create MOnth column
quad2018c$Date = as.Date(quad2018c$Date,format='%Y/%m/%d')
quad2018c$Month = format(quad2018c$Date,'%m') %>% as.numeric()
quad2018c$Month = month.name[quad2018c$Month]

# Station should be Locality, Site, Bar
quad2018c$Station_old = quad2018c$Station
quad2018c$Station = paste0(quad2018c$Locality,quad2018c$Site,quad2018c$Bar)

# rename Height col to Size
colnames(quad2018c)[colnames(quad2018c)=='Height'] <- 'Size'

# Treatment column
quad2018c$Treatment = rep('control')

# Replicate column
quad2018c$Replicate = rep(1)

# create Quadrat_ID col
quad2018c.locations = make_quadrat_id_dataframe(quad2018c,c('Quadrat','Quad_Lat','Quad_Long','Center_Lat','Center_Long','Rand_Coord','Rand_Dist','Quad_type','Quad_area','Quad_Depth'))

# attache Quadrat_ID to quad2018 df
quad2018c_modified = merge(quad2018c,quad2018c.locations,all.x=T)

# select correct columns
quad.2018c = quad2018c_modified[,c('Date','Month','Locality','Site','Bar','Station','Counter','Quadrat_ID','Live_Dead','Size','Count','Treatment')]

# =====================================================================================================================
# combine all quadrat data and location data

# locations
quadrat.locations = rbind.fill(quad2012.locations,quad2013.locations,quad2015.locations,quad2018.locations,quad2018b.locations,quad2018c.locations)

quadrat.combined = rbind(quad.2012,quad.2013,quad.2015,quad.2018,quad.2018b,quad.2018c)

# some of the Live oysters are recorded with "Li" instead of "L". Standardize.
quadrat.combined$Live_Dead[quadrat.combined$Live_Dead=='Li'] = 'L'

# put rows in order of quadratID (will be in order by date also)
quadrat.combined=quadrat.combined[order(quadrat.combined$Quadrat_ID),]
quadrat.locations=quadrat.locations[order(quadrat.locations$Quadrat_ID),]

write.csv(quadrat.locations,'Oyster_data/Quadrat/quadrat.locations.csv',row.names=F)
write.csv(quadrat.combined,'Oyster_data/Quadrat/quadrat_combined.csv',row.names = F)
