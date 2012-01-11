# Adapted from python_example.py by:
# Steve Ivy <steveivy@gmail.com>
# http://monkinetic.com
#
# When invoked by Statsd.create() this file expects local_settings.py
# to be in the same dir, with statsd host and port information:
#
# statsd_host = 'localhost'
# statsd_port = 8125
#
# Sends statistics to the stats daemon over UDP

from pprint import pprint
import sys, random, socket
from contextlib import closing

class Statsd:

    def __init__(self, host, port):
        self.addr = (host, port)

    @staticmethod
    def create(cls):
        """
        Creates a Statsd instance using settings from local_settings.py
        """
        import local_settings as settings
        host = settings.statsd_host
        port = settings.statsd_port
        return cls(host, port)

    def timing(self, stat, time, sample_rate=1):
        """
        Log timing information
        >>> statsd.timing('some.time', 500)
        """
        stats = {}
        stats[stat] = "%d|ms" % time
        self.send(stats, sample_rate)

    def increment(self, stats, sample_rate=1):
        """
        Increments one or more stats counters
        >>> statsd.increment('some.int')
        >>> statsd.increment('some.int',0.5)
        """
        self.update_stats(stats, 1, sample_rate)

    def decrement(self, stats, sample_rate=1):
        """
        Decrements one or more stats counters
        >>> statsd.decrement('some.int')
        """
        self.update_stats(stats, -1, sample_rate)

    def update_stats(self, stats, delta=1, sampleRate=1):
        """
        Updates one or more stats counters by arbitrary amounts
        >>> statsd.update_stats('some.int',10)
        """
        if (type(stats) is not list):
            stats = [stats]
        data = {}
        for stat in stats:
            data[stat] = "%s|c" % delta

        self.send(data, sampleRate)

    def send(self, data, sample_rate=1):
        """
        Squirt the metrics over UDP
        """
        sampled_data = {}

        if(sample_rate < 1):
            if random.random() <= sample_rate:
                for stat in data.keys():
                    value = data[stat]
                    sampled_data[stat] = "%s|@%s" %(value, sample_rate)
        else:
            sampled_data=data

        with closing(socket.socket(socket.AF_INET, socket.SOCK_DGRAM)) as udp_sock:
            try:
                for stat in sampled_data.keys():
                    value = data[stat]
                    send_data = "%s:%s" % (stat, value)
                    udp_sock.sendto(send_data, self.addr)
            except:
                print "Unexpected error:", pprint(sys.exc_info())

if __name__ == '__main__':
    statsd = Statsd('localhost', 8125)

    statsd.timing('example.time', random.randint(1, 1000))

    statsd.increment('example.counter.inc')
    statsd.increment('example.counter.inc', random.randint(1, 10))

    statsd.decrement('example.counter.dec')
    statsd.decrement('example.counter.dec', random.randint(1, 10))
