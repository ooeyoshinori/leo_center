#======================================================================
#
# LeoFS
#
# Copyright (c) 2012-2013 Rakuten, Inc.
#
# This file is provided to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file
# except in compliance with the License.  You may obtain
# a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#======================================================================
class LeoCenter
  module SystemConf; end

  namespace "/system_conf" do
    SystemConf::Properties = {
      version: "LeoFS version",
      n: "The number of replicas",
      r: "The number of successful READs",
      w: "The number of successful WRITEs",
      d: "The number of successful DELETEs"
    }

    get "/list.json" do
      system_info = @@manager.status.system_info

      data = SystemConf::Properties.map do |property, text|
        {
          name: text,
          value: system_info.__send__(property)
        }
      end

      { data: data }.to_json
    end
  end
end
