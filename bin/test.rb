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
exporter = GdcExporter.new({})
pid = 's70v91nwm78n3cdaydsvejcnbhvma1l6'
GoodData.project = pid
exporter.export_objects(pid, ["anANdK89eBKU"], "/Users/zdenek/temp/goodsales")
pid = 'jspt2m3vnztmx23diefubnhu8xu7ly8c'
GoodData.project = pid
importer = GdcImporter.new({})
importer.import(pid, "anANdK89eBKU", "/Users/zdenek/temp/goodsales")




