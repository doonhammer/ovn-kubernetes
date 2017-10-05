# Copyright (C) 2016 Nicira, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ovs.vlog
import ovn_k8s.processor

vlog = ovs.vlog.Vlog("connprocessor")


class ConnectivityProcessor(ovn_k8s.processor.BaseProcessor):

    def _process_pod_event(self, event):
        if event.event_type == "DELETED":
            vlog.info("Received a pod delete event %s" % (event.metadata))
            self.mode.delete_logical_port(event)
        else:
            vlog.info("Received a pod ADD/MODIFY event %s" % (event.metadata))
            #
            # Check the event metadata to see if there are multiple interfaces defined
            #
            # if (ovn_interface)
            #  then for number of interfaces defined.
            #
            data = event.metadata
            vlog.info("Getting data: %s" % data)
            if 'annotations' in data['metadata']:
                vlog.info("Getting data.metadata: %s" % data['metadata'])
                if 'networks' in data['metadata']['annotations']:
                    vlog.info("Getting data.metadata.networks: %s" % data['metadata']['networks'])
                    networkList = data['metadata']['annotations']['networks']
                    for interface in networkList:
                        vlog.info("Creating logical port for: %s" % interface['name'])
                        self.mode.create_logical_port(event,interface['name'])
            else:
                #
                # TODO the nested logic here is wrong if annotations other than networks exist
                # the default is just attach ovn metadata
                #
                vlog.info("Creating logical port for default ovn interface")
                self.mode.create_logical_port(event)

    def _process_service_event(self, event):
        if event.event_type == "DELETED":
            vlog.dbg("Received a service delete event %s" % (event.metadata))
        else:
            vlog.dbg("Received a service ADD/MODIFY event %s"
                     % (event.metadata))
        self.mode.update_vip(event)

    def _process_endpoint_event(self, event):
        if event.event_type != "DELETED":
            vlog.dbg("Received a endpoint ADD/MODIFY event %s"
                     % (event.metadata))
            self.mode.add_endpoint(event)

    def process_events(self, events):
        for event in events:
            data = event.metadata
            if not data:
                continue

            if data['kind'] == "Pod":
                self._process_pod_event(event)
            elif data['kind'] == "Service":
                self._process_service_event(event)
            elif data['kind'] == "Endpoints":
                self._process_endpoint_event(event)


def get_event_queue():
    return ConnectivityProcessor.get_instance().event_queue


def run_processor():
    ConnectivityProcessor.get_instance().run()
