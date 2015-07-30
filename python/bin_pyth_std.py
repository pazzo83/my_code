import struct

def calc_vwap(price_dict):
	tot_shares = 0
	prx_wgt = 0

	for price, trade_vol in price_dict.iteritems():
		tot_shares += trade_vol
		prx_wgt = prx_wgt + (price * trade_vol)

	return prx_wgt / tot_shares

filename = 'trades.bin'
read_fmt = 'rb'

file_out = 'results.txt'

full_conversion = struct.Struct('< 1s 1s b 1s I Q 8s d')

trade_vol_by_exch = dict()
vwap_dict = dict()

f = open(filename, 'rb')
out = open(file_out, 'w')

line = f.read(32)
while line != '':
	test = full_conversion.unpack(line)

	exch = test[2]
	trade_vol = test[4]
	symb = test[6]
	price = test[7]

	#storing trade vol by exchange
	if trade_vol_by_exch.has_key(exch):
		curr_trade_vol = trade_vol_by_exch.get(exch, 0)
		new_trade_vol = curr_trade_vol + trade_vol
		trade_vol_by_exch[exch] = new_trade_vol
	else:
		trade_vol_by_exch[exch] = trade_vol

	#calculating vwap
	if vwap_dict.has_key(exch):
		if vwap_dict[exch].has_key(symb):
			if vwap_dict[exch][symb].has_key(price):
				curr_shares_prx = vwap_dict[exch][symb].get(price, 0)
				new_shares_prx = curr_shares_prx + trade_vol
				vwap_dict[exch][symb][price] = new_shares_prx
			else:
				vwap_dict[exch][symb][price] = trade_vol
		else:
			vwap_dict[exch][symb] = {price : trade_vol}
	else:
		vwap_dict[exch] = {symb : { price : trade_vol}}

	test_str = ' '.join(map(str, test))
	out.write(test_str)
	out.write('\n')
	line = f.read(32)

f.close()
out.close()

print "Exch Shares"
for exch, trade_vol in trade_vol_by_exch.iteritems():
	print "{0}: {1}".format(exch, trade_vol)

print '___________________'

print "Exch Symb VWAP"
for exch, symbs in vwap_dict.iteritems():
	for symb, price_dict in symbs.iteritems():
		vwap = calc_vwap(price_dict)
		print '{0} {1} {2}'.format(exch, symb, vwap)