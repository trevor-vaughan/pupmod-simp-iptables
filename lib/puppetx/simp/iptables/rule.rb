module PuppetX
  module SIMP
    class IPTables::Rule

      attr_reader :rule
      attr_reader :rule_type
      attr_reader :table
      attr_reader :chain
      attr_reader :jump
      attr_reader :input_interface
      attr_reader :output_interface
      attr_reader :rule_hash

      # This is true if the rule has more than just a jump in it.
      attr_reader :complex

      def self.to_hash(rule)
        require 'optparse'
        require 'shellwords'


        opt_arr = Shellwords.shellwords(rule)

        opt_parser = OptionParser.new

        opts = Hash.new
        negate = false

        until opt_arr.empty? do
          begin
            opt_parser.parse!(opt_arr)
            opt_arr.shift
          rescue OptionParser::InvalidOption => e
            e.recover(opt_arr)

            key = opt_arr.shift.gsub(/^-*/,'')
            value = []

            opts[key] ||= { :value => nil, :negate => negate }

            while opt_arr.first && (opt_arr.first[0] != '-')
              value << opt_arr.shift
            end

            if !value.empty? && (value.last.strip == '!')
              value.pop
              negate = true
            else
              negate = false
            end

            opts[key][:value] = value.join(' ')
          end
        end

        return opts
      end

      def self.parse(rule)
        output = {
          :chain => nil,
          :jump => nil,
          :input_interface => nil,
          :output_interface => nil
        }

        rule_hash = PuppetX::SIMP::IPTables::Rule.to_hash(rule)

        if rule_hash
          chain = rule_hash.find{ |k,_| ['A','D','I','R','N','P'].include?(k)}
          output[:chain] = chain.last[:value] if chain

          jump = rule_hash.find{ |k,_| ['j'].include?(k)}
          output[:jump] = jump.last[:value] if jump

          input_interface = rule_hash.find{ |k,_| ['i'].include?(k)}
          output[:input_interface] = input_interface.last[:value] if input_interface

          output_interface = rule_hash.find{ |k,_| ['o'].include?(k)}
          output[:output_interface] = output_interface.last[:value] if output_interface
        end

        output[:rule_hash] = rule_hash

        return output
      end

      # Create the particular rule. The containing table should be passed in
      # for future reference.
      def initialize(rule_str, table)
        @rule = rule_str.strip
        @rule_type = :rule

        if table.nil? or table.empty? then
          raise(Puppet::Error, "All rules must have an associated table: '#{rule}'")
        end

        @table = table.strip

        parsed_rule = PuppetX::SIMP::IPTables::Rule.parse(rule)

        @chain = parsed_rule[:chain]
        @jump = parsed_rule[:jump]
        @input_interface = parsed_rule[:input_interface]
        @output_interface = parsed_rule[:output_interface]
        @rule_hash = parsed_rule[:rule_hash]

        @rule_families = get_rule_families(@rule_hash)

require 'pry'
binding.pry

        @complex = true

        if @rule == 'COMMIT' then
          @rule_type = :commit
        elsif @rule =~ /^\s*:(.*)\s+(.*)\s/
          @chain = $1
          @rule = ":#{@chain} #{$2} [0:0]"
          @rule_type = :chain
        end

        # If there is only a jump, then the rule is simple
        if (parsed_rule[:rule_hash].keys - ['A','D','I','R','N','P','j']).empty?
          @complex = false
        end
      end

      def get_rule_families(rule_hash)
        families = ['ipv4', 'ipv6']

        return families unless (rule_hash && !rule_hash.empty?)

        rule_hash.each_pair do |k,v|
          addr = normalize_address(v[:value])

          next unless addr.is_a?(IPAddr)

          if addr.ipv6?
            return ['ipv6']
          elsif addr.ipv4?
            return ['ipv4']
          end
        end

        return families
      end

      def to_s
        return @rule
      end

      # Run through all source and destination addresses and attempt resolution
      #
      # If resolution is not possible, leave the rule as-is and let iptables
      # handle it
      #
      # @param to_convert [Array[String]] Options to be converted, if possible
      def resolve_addresses!(to_convert = ['-s', '--source', '-d', '--destination'])
        require 'ipaddr'
        require 'resolv'

        to_convert.each do |opt|
          val = @rule_hash[opt]

          if val
            val.split(',').each do |host|
              begin
                IPAddr.new(host)
              rescue
                # Not an IP Address, process
                debug("Resolving '#{host}' via Hosts")

                addresses = []
                begin
                  addresses = Resolv::Hosts.new.getaddresses(to_check)

                  if addresses.empty?
                    debug("Resolving '#{host}' via DNS")

                    Resolv::DNS.open do |dns|
                      addresses = dns.getresources(host, Resolv::DNS::Resource::IN::A)
                      addresses += dns.getresources(host, Resolv::DNS::Resource::IN::AAAA)

                      addresses = addresses.map{|x| "#{x.address}"}.sort.uniq
                    end
                  end
                rescue Resolv::ResolvError => e
                  debug("Could not resolve '#{host}': #{e}")
                  resolv_failure = true
                rescue Resolv::ResolvTimeout => e
                  warning("Timeout when resolving '#{host}': #{e}")
                  resolv_failure = true
                end

                if resolv_failure or addresses.empty?
                  next
                else
                  @rule_hash[opt] = addresses.join(',')
                end
              end
            end
          end
        end
      end

      def normalize_address(address)
        require 'ipaddr'

        begin
          return IPAddr.new(address)
        rescue ArgumentError, NoMethodError, IPAddr::InvalidAddressError
          return address
        end
      end

      def normalize_addresses(to_normalize)
        return Array(normalized_array).map{|x| normalize_address(x)}
      end

      def ==(other_rule)
        return false if (other_rule.nil? || other_rule.rule_hash.nil? || other_rule.rule_hash.empty?)

        return false if (@rule_hash.size != other_rule.rule_hash.size)

        local_hash = @rule_hash.dup
        other_hash = other_rule.rule_hash.dup

        local_hash.each_key do |key|
          local_hash[key][:value] = normalize_addresses(local_hash[key][:value]) if (other_hash[key] && other_hash[key][:value])
        end

        other_hash.each_key do |key|
          other_hash[key][:value] = normalize_addresses(other_hash[key][:value]) if (other_hash[key] && other_hash[key][:value])
        end

        return local_hash == other_hash
      end
    end
  end
end
