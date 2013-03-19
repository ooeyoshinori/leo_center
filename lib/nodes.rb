class LeoTamer
  namespace "/nodes" do
    before do
      halt 401 unless session[:admin]
    end

    get "/list.json" do
      {
        data: @@manager.status.node_list.map do |node|
          { name: node.node }
        end
      }.to_json
    end

    get "/status.json" do
      node_list = @@manager.status.node_list
      data = node_list.map do |node|
        case node.type
        when "S"
          type = "Storage"
        when "G"
          type = "Gateway"
        else
          raise Error, "unknown node type: #{node.type}"
        end

        {
          type: type,
          node: node.node,
          status: node.state,
          ring_hash_current: node.ring_cur,
          ring_hash_previous: node.ring_prev,
          joined_at: Integer(node.joined_at)
        }
      end

      { data: data }.to_json
    end

    module Nodes
      module LeoFSRelatedConfig
        Group = "1. LeoFS related Items"
        Properties = {
          version: "LeoFS Version",
          log_dir: "Log Directory",
          ring_cur: "Current Ring-hash",
          ring_prev: "Previous Ring-hash"
        }
      end

      module ErlangRelatedItems
        Group = "2. Erlang related Items"
        Properties = {
          vm_version: "VM Version",
          total_mem_usage: "Total Memory Usage",
          system_mem_usage: "System Memory Usage",
          procs_mem_usage: "Procs Memory Usage",
          ets_mem_usage: "ETS Memory Usage",
          num_of_procs: "# of Procs",
          limit_of_procs: "Limit of Procs",
          thread_pool_size: "Thread Pool Size"
        }
      end
      
      module StorageStatus
        Group = "3. Storage related Items"
        Properties = {
          active_num_of_objects: "Active # of Objects",
          total_num_of_objects: "Total # of Objects",
          active_size_of_objects: "Active Size of Objects",
          total_size_of_objects: "Total Size of Objects",
          #ratio_of_active_size: "Ratio of Active Size",
          #last_compaction_start: "Last Compaction Start", #XXX: CompactStatus has same property
          #last_compaction_end: "Last Compaction End"
        }
      end
      
      module CompactStatus
        Group = "4. Compaction Status"
        Properties = {
          status: "Current Status",
          last_compaction_start: "Last Compaction Start",
          total_targets: "Total Targets",
          num_of_pending_targets: "# of Pending Targets",
          num_of_ongoing_targets: "# of Ongoing Targets",
          num_of_out_of_targets: "# of Out of Targets"
        }
      end
    end

    get "/detail.json" do
      node, type = required_params(:node, :type)

      node_stat = @@manager.status(node).node_stat

      result = Nodes::LeoFSRelatedConfig::Properties.map do |property, text|
        { 
          name: text,
          value: node_stat.__send__(property),
          group: Nodes::LeoFSRelatedConfig::Group
        }
      end

      result.concat(Nodes::ErlangRelatedItems::Properties.map do |property, text|
        { 
          name: text,
          value: node_stat.__send__(property),
          group: Nodes::ErlangRelatedItems::Group
        }
      end)

      if type == "Storage"
        begin
          compact_status = @@manager.compact_status(node)
          storage_stat = @@manager.du(node)
        rescue => ex
          warn ex.message
        else
          result.concat(Nodes::CompactStatus::Properties.map do |property, text|
            { 
              name: text,
              value: compact_status.__send__(property),
              id: property,
              group: Nodes::CompactStatus::Group
            }
          end)

          result.concat(Nodes::StorageStatus::Properties.map do |property, text|
            { 
              name: text,
              value: storage_stat.__send__(property),
              id: property,
              group: Nodes::StorageStatus::Group
            }
          end)

          result.push({
            name: "Ratio of Active Size",
            value: "#{storage_stat.ratio_of_active_size}%",
            id: "ratio_of_active_size",
            group: Nodes::StorageStatus::Group
          })
        end
      end

      { data: result }.to_json
    end

    post "/execute" do
      node, command = required_params(:node, :command)
      command = command.to_sym
      confirm_password

      case command
      when :resume, :suspend, :detach
        @@manager.__send__(command, node)
      else
        raise "invalid operation command: #{command}"
      end
      200
    end

    post "/rebalance" do
      confirm_password
      @@manager.rebalance
    end

=begin
    post "/compaction" do
      node = required_params(:node)
      confirm_password
      @@manager.compact(node)
    end
=end

    post "/compact_start" do
      node, num_of_targets, num_of_compact_proc = required_params(:node, :num_of_targets, :num_of_compact_proc)
      @@manager.compact_start(node, num_of_targets, num_of_compact_proc)
    end

    post "/compact_suspend" do
      node = required_params(:node)
      @@manager.compact_suspend(node)
    end

    post "/compact_resume" do
      node = required_params(:node)
      @@manager.compact_resume(node)
    end
  end
end
