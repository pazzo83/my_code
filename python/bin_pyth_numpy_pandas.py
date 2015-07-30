import numpy
import pandas

filename = 'trades.bin'
#get data types
dt = numpy.dtype([('msg_type', '<c'), ('side', '<c'), ('exch', '<b'), ('condition', '<c'), ('size', 'u4'), ('time', 'u8'), ('symbol', '<a8'), ('price', '<d')])

data = numpy.fromfile(filename, dtype=dt)

#data_frame
data_df = pandas.DataFrame(data)

#readible
print data_df

#vol per exchange
vol_per = data_df.groupby('exch').sum()['size']

print vol_per

#vwap per symb per exch
#first add weighted price to df
data_df['wgt_prx'] = data_df['price'] * data_df['size']

#now group by exch & symbol and get sums
vwap_base_sum = data_df.groupby(['exch', 'symbol']).sum()

#create vwap column
vwap_base_sum['vwap'] = vwap_base_sum['wgt_prx'] / vwap_base_sum['size']

print vwap_base_sum['vwap']
