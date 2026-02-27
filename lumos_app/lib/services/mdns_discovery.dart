import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

class MdnsDiscovery {
  static const String serviceType = '_lumos-agent._tcp';
  static const Duration discoveryTimeout = Duration(seconds: 5);

  /// Discover Lumos agents via mDNS
  static Future<List<Map<String, dynamic>>> discoverAgents({
    Duration timeout = discoveryTimeout,
  }) async {
    final discovered = <String, Map<String, dynamic>>{};
    MDnsClient? client;

    try {
      client = MDnsClient();
      await client.start();

      // Query for Lumos agents
      await for (final ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
          )
          .timeout(timeout)) {
        // Get SRV record for the service
        await for (final srv in client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(const Duration(seconds: 2))) {
          // Get A/AAAA records for the host
          final addresses = <String>[];
          
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(const Duration(seconds: 1))) {
            addresses.add(ip.address.address);
          }

          if (addresses.isNotEmpty) {
            final address = '${addresses.first}:${srv.port}';
            final agentId = _extractAgentId(ptr.domainName);
            
            discovered[address] = {
              'agent_id': agentId,
              'address': address,
              'host': srv.target,
              'port': srv.port,
              'discovered_via': 'mdns',
            };
          }
        }
      }
    } on TimeoutException {
      // Discovery timeout - return what we found
    } catch (e) {
      // mDNS discovery failed - return partial results
      // Consider logging: print('mDNS discovery error: $e');
    } finally {
      client?.stop();
    }

    return discovered.values.toList();
  }

  /// Check if mDNS is available on this device
  static Future<bool> isAvailable() async {
    MDnsClient? client;
    try {
      client = MDnsClient();
      await client.start();
      return true;
    } catch (e) {
      return false;
    } finally {
      client?.stop();
    }
  }

  /// Extract agent ID from mDNS domain name
  /// Example: "DESKTOP-ABC123._lumos-agent._tcp.local" -> "DESKTOP-ABC123"
  static String _extractAgentId(String domainName) {
    final parts = domainName.split('.');
    if (parts.isNotEmpty) {
      return parts.first;
    }
    return domainName;
  }
}
