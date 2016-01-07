# -*- encoding : utf-8 -*-

require 'gnuplot'

namespace :graphs do

  def select_as_columns(sql)
    hash_array = User.connection.select_all(sql)
    return if hash_array.empty?
    columns = hash_array.first.values.map { |val| [val] }
    if hash_array.size > 1
      hash_array[1..-1].each do |result|
        result.values.each.with_index do |value, i|
          columns[i] << value
        end
      end
    end
    columns
  end

  def create_dataset(data, options)
    default = {:using => "1:2"} #in most cases, we just want the first 2 columns
    options = default.merge(options)
    Gnuplot::DataSet.new(data) do |ds|
      options.keys.each do |option|
        ds.send("#{option}=", options[option])
       end
    end
  end

  task :generate_user_use_graph => :environment do
    # set the local font path for the current task
    ENV["GDFONTPATH"] = "/usr/share/fonts/truetype/ttf-bitstream-vera"

    active_users = "SELECT DATE(created_at), COUNT(distinct user_id) " \
                   "FROM info_requests GROUP BY DATE(created_at) " \
                   "ORDER BY DATE(created_at)"

    confirmed_users = "SELECT DATE(created_at), COUNT(*) FROM users " \
                      "WHERE email_confirmed = 't' " \
                      "GROUP BY DATE(created_at) " \
                      "ORDER BY DATE(created_at)"

    # here be database-specific dragons...
    # this uses a window function which is not supported by MySQL, but
    # is reportedly available in MariaDB from 10.2 onward (and Postgres 9.1+)
    aggregate_signups = "SELECT DATE(created_at), COUNT(*), SUM(count(*)) " \
                        "OVER (ORDER BY DATE(created_at)) " \
                        "FROM users GROUP BY DATE(created_at)"

    Gnuplot.open(false) do |gp|
      Gnuplot::Plot.new(gp) do |plot|
        plot.terminal("png font 'Vera.ttf' 9 size 1200,400")
        plot.output(File.expand_path("public/foi-user-use.png", Rails.root))

        #general settings
        plot.unset(:border)
        plot.unset(:arrow)
        plot.key("left")
        plot.tics("out")

        # x-axis
        plot.xdata("time")
        plot.set('timefmt "%Y-%m-%d"')
        plot.set('format x "%d %b %Y"')
        plot.set("xtics nomirror")

        # primary y-axis
        plot.set("ytics nomirror")
        plot.ylabel("number of users on the calendar day")

        # secondary y-axis
        plot.set("y2tics tc lt 2")
        plot.set('y2label "cumulative total number of users" tc lt 2')
        plot.set('format y2 "%.0f"')

        # start plotting the data from largest to smallest so
        # that the shorter bars overlay the taller bars

        # plot all users
        options = {:with => "impulses", :linecolor => 3, :linewidth => 15,
                   :title => "users each day ... who registered"}
        all_users = select_as_columns(aggregate_signups)
        plot.data << create_dataset(all_users, options)

        # plot confirmed users
        options[:title] = "... and since confirmed their email"
        options[:linecolor] = 4
        plot.data << create_dataset(select_as_columns(confirmed_users), options)

        # plot active users
        options[:with] = "lines"
        options[:title] = "... who made an FOI request"
        options[:linecolor] = 6
        options.delete(:linewidth)
        plot.data << create_dataset(select_as_columns(active_users), options)

        # plot cumulative user totals
        options[:title] = "cumulative total number of users"
        options[:axes] = "x1y2"
        options[:linecolor] = 2
        options[:using] = "1:3"
        plot.data << create_dataset(all_users, options)
      end
    end
  end

  task :generate_request_creation_graph => :environment do
    # set the local font path for the current task
    ENV["GDFONTPATH"] = "/usr/share/fonts/truetype/ttf-bitstream-vera"

    def assemble_sql(where_clause="")
      "SELECT DATE(created_at), COUNT(*) " \
              "FROM info_requests " \
              "WHERE #{where_clause} " \
              "AND PROMINENCE != 'backpage' " \
              "GROUP BY DATE(created_at)" \
              "ORDER BY DATE(created_at)"
    end

    Gnuplot.open(false) do |gp|
      Gnuplot::Plot.new(gp) do |plot|
        plot.terminal("png font 'Vera.ttf' 9 size 1600,600")
        plot.output(File.expand_path("public/foi-live-creation.png", Rails.root))

        #general settings
        plot.unset(:border)
        plot.unset(:arrow)
        plot.key("left")
        plot.tics("out")

        # x-axis
        plot.xdata("time")
        plot.set('timefmt "%Y-%m-%d"')
        plot.set('format x "%d %b %Y"')
        plot.set("xtics nomirror")
        plot.xlabel("status of requests that were created on each calendar day")

        # primary y-axis
        plot.ylabel("number of requests created on the calendar day")

        # secondary y-axis
        plot.set("y2tics tc lt 2")
        plot.set('y2label "cumulative total number of requests" tc lt 2')
        plot.set('format y2 "%.0f"')

        # get the data, plot the graph

        options = {:with => "impulses", :linecolor => 8, :linewidth => 4,
                   :title => "awaiting_response"}

        # here be database-specific dragons...
        # this uses a window function which is not supported by MySQL, but
        # is reportedly available in MariaDB from 10.2 onward (and Postgres 9.1+)
        sql = "SELECT DATE(created_at), COUNT(*), SUM(count(*)) " \
              "OVER (ORDER BY DATE(created_at)) " \
              "FROM info_requests " \
              "WHERE prominence != 'backpage' " \
              "GROUP BY DATE(created_at)"

        all_requests = select_as_columns(sql)
        plot.data << create_dataset(data, options)

        # start plotting the data from largest to smallest so
        # that the shorter bars overlay the taller bars

        sql = assemble_sql("described_state NOT IN ('waiting_response')")
        options[:title] = "waiting_clarification"
        options[:linecolor] = 3
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification')")
        options[:title] = "not_held"
        options[:linecolor] = 9
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held')")
        options[:title] = "rejected"
        options[:linecolor] = 6
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected')")
        options[:title] = "successful"
        options[:linecolor] = 2
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful')")
        options[:title] = "partially_successful"
        options[:linecolor] = 10
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful')")
        options[:title] = "requires_admin"
        options[:linecolor] = 5
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin')")
        options[:title] = "gone_postal"
        options[:linecolor] = 7
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal')")
        options[:title] = "internal_review"
        options[:linecolor] = 4
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal', 'internal_review')")
        options[:title] = "error_message"
        options[:linecolor] = 12
        plot.data << create_dataset(select_as_columns(sql), options)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal', 'internal_review', 'error_message')")
        options[:title] = "user_withdrawn"
        options[:linecolor] = 13
        plot.data << create_dataset(select_as_columns(sql), options)

        # plot the cumulative counts
        options[:with] = "lines"
        options[:linecolor] = 2
        options[:title] = "cumulative total number of requests"
        options[:using] = "1:3"
        options[:axes] = "x1y2"
        options.delete(:linewidth)
        plot.data << create_dataset(all_requests, options)
      end
    end
  end
end

