class ReportsController < ApplicationController

  # override the application accessLevel method
  def checkAccess
    #only the ward council has access
    if hasAccess(2)
      true
    else
      deny_access
    end
  end

  def allReports
    @showLink = false
    @monthly_info = getMonthlyEvents(0)
    @names = Person.selectionList
    render :action=>"monthlyReport"
  end

  def monthlyReport
    @showLink = true
    range = 3.months.ago.at_beginning_of_month.to_date
    @monthly_info = getMonthlyEvents(range)
    @names = Person.selectionList
  end

  def getMonthlyEvents(range)
    @events = Event.includes(:family => { :teaching_routes => {} }).where("(category != 'Attempt' and 
                             category != 'Other' and  
                             category != 'MoveIn' and
                             category != 'MoveOut' and
                             category is not NULL) and (date > ?)", range)
                             .order('date DESC')

    monthly_info = []

    event_months = @events.group_by { |month| month.date.at_beginning_of_month }
    event_months.each do |month, events|
      month_info = {:month => month}
      events.sort! { |a,b| a.family.name <=> b.family.name }
      events_by_families = events.group_by { |event| event.family_id }
      hp, elders, vt, unassigned = categorizeVisits(events_by_families)

      month_info[:families_visited_count] = events_by_families.keys.size
      month_info[:hp] = hp
      month_info[:elders] = elders
      month_info[:vt] = vt
      month_info[:unassigned] = unassigned
      monthly_info << month_info
    end

    monthly_info
  end

  def was_family_visited
    category = params[:category]
    year = params[:year].to_i
    month = params[:month].to_i

    @start_date = Date.new(year, month, 1)
    end_date = Date.new(year, month, -1)

    @category = category
    @categories = ["Home Teaching", "Visiting Teaching"]

    @was_visited = Family.find_all_by_member_and_current(true,true, :order => :name).collect do |family|
      size = Event.where("category = ? and date >= ? and date <= ? and family_id = ?", category, @start_date, end_date, family.id).size
      {family: family, visited: size > 0}
    end
  end

  def progressReport
    @family = Family.find(params[:id])
    if @family.progress_report.nil?
      @family.progress_report = ProgressReport.create
    end
    @report = @family.progress_report
  end

  def saveProgressReport
    @family = Family.find(params[:id])
    @report = @family.progress_report

    if @report.update_attributes(params[:progress_report])
      redirect_to '/reports/progress/' + @family.id.to_s
    else
      redirect_to '/reports/progress/' + @family.id.to_s
    end
  end

  private

  def categorizeVisits(family_events)
    elders = Array.new
    hp = Array.new
    vt = Array.new
    unassigned = Array.new
    family_events.each do |family_id, events| 
      family = Family.find(family_id)
      vt_events = Array.new
      ht_events = Array.new
      other_events = Array.new

      events.each do |e|
        if e.category == "Visiting Teaching"
          vt_events << e
          puts "VT Event"
        elsif e.category == "Home Teaching"
          ht_events << e
          puts "HT Event"
        else
          other_events << e
          puts "Other Event"
        end
      end

      unless vt_events.empty?
        vt << [family_id, vt_events]
      end

      unless ht_events.empty?
        if family.teaching_routes.size == 0
          other_events.concat ht_events
        elsif family.teaching_routes[0].category == "High Priests Group"
          hp << [family_id, ht_events]
        elsif family.teaching_routes[0].category == "Elders Quorum"
          elders << [family_id, ht_events]
        else
          other_events.concat ht_events
        end
      end

      unless other_events.empty?
        unassigned << [family_id, other_events]
      end

    end
    return hp, elders, vt, unassigned
  end

end
