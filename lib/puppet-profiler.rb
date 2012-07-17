class PuppetProfiler
  def self.get_tree(line, tree, time)
    if line.length == 0 
      return tree
    end
    while line =~ /^(\/[^\]]+\[[^\]]+\]){1}/
	parent = $1
        parent = parent[1..-1]
        if not tree.has_key?(parent)
	  tree[parent] = [0, 0]
        end
	item = tree[parent]
        tree[parent] = [item[0] + time, item[1] + 1]
	line = line[(parent.length + 1)..-1]
    end
    return tree
  end
	
  def self.run(num_res, num_types, environment, really_run, cummulative)
    command = []
    command << 'puppet agent --test --evaltrace --color=false'
    command << "--environment=#{environment}"
    if not really_run
        command << '--noop'
    end

    output = `#{command.join(' ')}`.split("\n")
    self.eval(output, num_res, num_types, cummulative)
  end

  def self.eval(output, num_res, num_types, cummulative)
    times = []
    times_by_type = {}
    path = {}
    resources = output.select { |line| 
      line =~ /.+: E?valuated in [\d\.]+ seconds$/
    }.each { |line|
      res_line, junk, eval_line = line.rpartition(':')
      if eval_line =~ / E?valuated in ([\d\.]+) seconds$/
        time = $1.to_f
      end
      junk, junk, res_line = res_line.partition(':')
      path = get_tree(res_line, path, time)
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

    if num_res > 0
      if cummulative
	times = []
	path.each {|key, value| times << [key, value[0], value[1]] }
      end

      puts "Top #{num_res} Puppet resources by runtime"
      puts "=================================="
      puts ""
      times.sort { |a, b| a[2] <=> b[2] }.reverse[0..num_res].each { |item|
        puts "#{format('%4s', item[2])}s - #{item[0]}[#{item[1]}]"
      }
    end

    if num_types > 0
      # need array for sorting, hashes are not sortable
      times_by_type_array = []
      puts ""
      puts "Top #{num_types} Puppet resources types by runtime"
      puts "=================================="
      puts ""
      times_by_type_array.sort { |a, b| a[1] <=> b[1] }.reverse[0..num_types].each { |item|
        puts "#{format('%4s', item[1])}s - #{item[0]} (calls #{item[2]}, #{format('%4s', item[1]/item[2])}s/call)"
      }
    end
  end
end
