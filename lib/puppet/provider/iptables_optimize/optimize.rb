Puppet::Type.type(:iptables_optimize).provide(:optimize) do
  desc <<-EOM
    Run through all of the proposed IPTables rules and optimize them where
    possible.

    Provides a fail-safe mode to just open port 22 in the case that the rules
    fail to apply.
  EOM

  commands :iptables_save => 'iptables-save'

  def initialize(*args)
    super(*args)

    require 'puppetx/simp/iptables'

    # Set up some reasonable defaults in the case of an epic fail.
    @ipt_config = {
      :id               => 'iptables',
      :running_config   => nil,
      :target_config    => nil,
      :changed          => false,
      :enabled          => !Facter.value('ipaddress').nil?,
      :default_config   => <<-EOM.gsub(/^\s+/,'')
        *filter
        :INPUT DROP [0:0]
        :FORWARD DROP [0:0]
        :OUTPUT ACCEPT [0:0]
        :LOCAL-INPUT - [0:0]
        -A INPUT -j LOCAL-INPUT
        -A FORWARD -j LOCAL-INPUT
        -A LOCAL-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        -A LOCAL-INPUT -i lo -j ACCEPT
        -A LOCAL-INPUT -m state --state NEW -m tcp -p tcp -m multiport --dports 22 -j ACCEPT
        -A LOCAL-INPUT -p icmpv6 --icmp-type echo-request -j ACCEPT
        -A LOCAL-INPUT -m state --state NEW -j LOG --log-prefix "IPT:"
        -A LOCAL-INPUT -j DROP
        COMMIT
        EOM
    }

    @ipt_config[:optimized_config] = @ipt_config[:default_config]
  end

  def optimize
    # These two are here instead of in initialize so that they don't
    # fail the entire build if they explode.
    @ipt_config[:running_config] = PuppetX::SIMP::IPTables.new(self.iptables_save)

    begin
      target_config = File.read(@resource[:name])
    rescue
      target_config = ""
    end

    @ipt_config[:target_config] = PuppetX::SIMP::IPTables.new(target_config)

    if resource[:ignore] && !resource[:ignore].empty?
      source_config = collect_rules.merge(@ipt_config[:running_config].preserve_match(resource[:ignore]))
    else
      source_config = collect_rules.merge(@ipt_config[:running_config])
    end

    # Start of the actual optmize code
    result = resource[:optimize]

    if @ipt_config[:enabled]
      if resource[:optimize]
        @ipt_config[:optimized_config] = source_config.optimize
      else
        @ipt_config[:optimized_config] = source_config
      end
    end

    # We go ahead and do the comparison here because passing the
    # appropriate values around becomes a mess in the log output.
    if @ipt_config[:target_config] != @ipt_config[:optimized_config]
      @ipt_config[:changed] = true
      unless resource[:optimize]
        result = :synchronized
      else
        result = :optimized
      end
    end

    return result
  end

  def system_insync?
    optimized_rules = @ipt_config[:optimized_config].report(resource[:ignore])
    running_rules = @ipt_config[:running_config].report(resource[:ignore])

    # We only care about tables that we're managing!
    (running_rules.keys - optimized_rules.keys).each do |chain|
      running_rules.delete(chain)
    end

    return running_rules == optimized_rules
  end

  def optimize=(should)
    require 'puppet/util/filetype'

    debug("Starting to apply the new ruleset")

    if @ipt_config[:changed]
      debug("Writing new #{@ipt_config[:id]} config file #{resource[:name]}")

      output_file = Puppet::Util::FileType.filetype(:flat).new(resource[:name], 0640)
      output_file.write(@ipt_config[:optimized_config].to_s + "\n")
    end
  end

  private

  def self.iptables_save
    %x{#{command(:iptables_save)}}
  end

  def collect_rules
    rules = []

    resource.catalog.resources.find_all do |res|
      res.type == :iptables_rule
    end.sort_by do |x|
      PuppetX::SIMP::Simplib.human_sort("#{x[:order]}#{x[:name]}")
    end.map do |rule|
      if rule[:resolve] == :true
        rule_content = rule[:content]

        if rule[:comment] && !rule[:comment].to_s.empty?
          debug("Adding comment #{rule[:comment]} to #{rule[:content]}")
          rule_content = %{#{rule_content} -m comment --comment "#{rule[:comment]}"}
        end

        new_rule = PuppetX::SIMP::IPTables::Rule.new(rule_content)

        new_rule.resolve! if (rule[:resolve] == :true)

        rules << new_rule if new_rule
      end
    end

    return PuppetX::SIMP::IPTables.new(rules.map{|rule| rule.to_s}.join("\n"))
  end
end
