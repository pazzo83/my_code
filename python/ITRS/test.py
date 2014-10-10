import time
import xmlrpclib

server = xmlrpclib.ServerProxy("http://localhost:52015/xmlrpc")
params = []
print "here i am"

try:
    params = ["queues", "myGroup"]
    print "now Im here"
    print server
    try:
        print "inside try"
        result = getattr(server, "myManEntPython.mySampler.createView")(params[0], params[1])
        
    except xmlrpclib.Fault, err:
        print "Error"
        print "Fault code: %d" % err.faultCode
        print "Fault string: %s" % err.faultString
    print "outside try"
        
    del params[:]
    
    params = ["totalQueues"]

    try:
        result = getattr(server, "myManEntPython.mySampler.myGroup-queues.addHeadline")(params[0])
    except xmlrpclib.Fault, err:
        print "Error"
        print "Fault code: %d" % err.faultCode
        print "Fault string: %s" % err.faultString
        
    params = ["queuesOffline"]
    result = getattr(server, "myManEntPython.mySampler.myGroup-queues.addHeadline")(params[0])
    
    dataMatrix = [
        ["queueName", "currentSize", "maxSize", "currentUtilisation", "status"],
        ["queue1", "332", "30000", "0.11", "online"],
        ["queue2", "0", "90000", "0", "offline"],
        ["queue3", "7331", "45000", "0.16", "online"]
    ]

    params[0] = dataMatrix
    result = getattr(server, "myManEntPython.mySampler.myGroup-queues.updateEntireTable")(params[0])
    
    params = ["totalQueues", 3]
    result = getattr(server, "myManEntPython.mySampler.myGroup-queues.updateHeadline")(params[0], params[1])
    
    params = ["queuesOffline", 1]
    result = getattr(server, "myManEntPython.mySampler.myGroup-queues.updateHeadline")(params[0], params[1])
    
    bSendTestData = True
    
    if bSendTestData:
        params[0] = "queue2.currentSize"
        for x in xrange(1,1000):
            params[1] = "%d" % x
            result = getattr(server, "myManEntPython.mySampler.myGroup-queues.updateTableCell")(params[0], params[1])
            time.sleep(1)

except xmlrpclib.Fault, err:
    print "Error"
    print "Fault code: %d" % err.faultCode
    print "Fault string: %s" % err.faultString
    