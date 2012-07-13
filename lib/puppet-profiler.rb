class PuppetProfiler
  def self.run(num_res, environment, really_run)
    command = []
    command << 'puppet agent --test --evaltrace --color=false'
    command << "--environment=#{environment}"
    if not really_run
        command << '--noop'
    end

    output = `#{command.join(' ')}`.split("\n")

    times = []
    times_by_type = {}
    resources = output.select { |line| 
      line =~ /.+: E?valuated in [\d\.]+ seconds$/
    }.each { |line|
      res_line, junk, eval_line = line.rpartition(':')
      if eval_line =~ / E?valuated in ([\d\.]+) seconds$/
        time = $1.to_f
      end
      junk, junk, res_line = res_line.partition(':')
      if res_line =~ /.*([A-Z][^\[]+)\[(.+?)\]$/
        type = $1
        title = $2
      end
      times << [type, title, time]
      if times_by_type.has_key?(type)
        item = times_by_type[type]
        item[0] += time
        item[1] += 1
      else
        item = [time, 1]
      end
      times_by_type[type] = item
    }

    # need array for sorting, hashes are not sortable
    times_by_type_array = []
    times_by_type.each {|key, value| times_by_type_array << [key, value[0], value[1]] }

    puts "Top #{num_res} Puppet resources by runtime"
    puts "=================================="
    puts ""
    times.sort { |a, b| a[2] <=> b[2] }.reverse[0..num_res].each { |item|
      puts "#{format('%4s', item[2])}s - #{item[0]}[#{item[1]}]"
    }
    puts ""
    puts "Top #{num_res} Puppet resources types by runtime"
    puts "=================================="
    puts ""
    times_by_type_array.sort { |a, b| a[1] <=> b[1] }.reverse[0..num_res].each { |item|
      puts "#{format('%4s', item[1])}s - #{item[0]} (calls #{item[2]})"
    }
  end
end
