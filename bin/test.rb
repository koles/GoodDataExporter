require '../lib/gdc_exporter'
require '../lib/gdc_importer'
require 'logger'

#GoodData.logger = Logger.new(STDOUT)

username = 'test@gooddata.com'
password = 'password'
GoodData::connect username, password


# adyD7xEmdhTx - dashboard
# agEEuYDOefRs - metric
# anANdK89eBKU - report
#exporter = GdcExporter.new({'attr.user.userid'=>'label.user.userid'})
#pid = 's70v91nwm78n3cdaydsvejcnbhvma1l6'
#GoodData.project = pid
#exporter.export(pid, ['asGmopIFbGKL'], '/Users/zdenek/temp/goodsales')
pid = 'vizl0lwawp6ovo9h9a17cylaq44qzmw8'
GoodData.project = pid
importer = GdcImporter.new({'attr.user.userid'=>'label.user.userid'})
importer.import(pid, ['asGmopIFbGKL'], false, '/Users/zdenek/temp/goodsales')




