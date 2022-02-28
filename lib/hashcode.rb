# frozen_string_literal: true

require_relative "hashcode/version"
require "set"

module Hashcode
  class Developer
    attr_accessor :name, :skills, :busy_until, :score

    def initialize(name)
      @name = name
      @skills = Hash.new(0)
      @busy_until = 0
      @score = 0
    end

    def level_up(role)
      if @skills[role.skill] <= role.level
        @skills[role.skill] += 1
      end
    end

    def valid_role(role)
      @skills[role.skill] >= role.level
    end

    def valid_time(project_start_day)
      project_start_day >= @busy_until
    end

    def assign(project, role, project_start_day)
      raise StandardError("Busy") unless valid_time(project_start_day)
      raise StandardError("Invalid role") unless valid_role(role)
      @busy_until = project_start_day + project.num_days
      level_up(role)
    end
  end

  class Project
    attr_accessor :name, :num_days, :score, :best_before, :roles, :roles_members, :current_members

    def initialize(name, num_days, score, best_before, roles, roles_members)
      @name = name
      @num_days = Integer(num_days)
      @score = Integer(score)
      @best_before = Integer(best_before)
      @roles = roles || {}
      @roles_members = roles_members || {}
      @current_members = Set.new
    end

    def start_day
      @best_before - @num_days
    end

    def add_member(role, member)
      @roles_members[role] = member
      @current_members << member
    end

    def get_members
      @roles.map { |role| @roles_members[role] }.compact
    end

    def reset
      @roles_members = {}
      @current_members = Set.new
    end
  end

  class Role
    attr_accessor :skill, :level

    def initialize(skill, level)
      @skill = skill
      @level = Integer(level)
    end
  end

  class HumanResources
    attr_accessor :developers

    def initialize(developers)
      @developers = developers
    end

    def find_candidates(role)
      skill = role.skill
      mentor_level = role.level - 1
      @developers.select do |developer|
        developer.skills[skill] >= mentor_level
      end
    end

    def fill_roles(project, start_day)
      project.roles.each do |role|
        candidates = find_candidates(role)

        candidate = candidates.find do |candidate|
          candidate.valid_time(start_day) &&
            candidate.valid_role(role) &&
            !project.current_members.include?(candidate)
        end

        unless candidate
          project.reset
          break
        end

        project.add_member(role, candidate)
      end
      project.get_members
    end
  end

  class Problem
    attr_accessor :developers, :projects, :iteration

    def initialize(developers, projects)
      @developers = developers
      @projects = projects
      @iteration = 0
    end

    def self.read(file_path)
      developers, projects = [], []

      file = File.open(file_path, "r")
      num_devs, num_projects = file.readline.split.map(&:to_i)

      num_devs.times do
        name, num_skills = file.readline.split

        developer = Developer.new(name)

        num_skills.to_i.times do
          skill_name, skill_level = file.readline.split
          developer.skills[skill_name] = Integer(skill_level)
        end

        developers << developer
      end

      num_projects.times do
        project_name, num_days, score, best_before, num_roles = file.readline.split

        roles = []
        num_roles.to_i.times do
          skill, level = file.readline.split
          roles << Role.new(skill, level)
        end

        projects << Project.new(project_name, num_days, score, best_before, roles, nil)
      end

      Problem.new(developers, projects)
    end

    def solve
      human_resources = HumanResources.new(@developers)
      solution = []
      @projects.each do |project|
        members = human_resources.fill_roles(project, project.start_day)
        solution << [project.name, members.map { |x| x.name }] if members
      end

      solution
    end

    def write(solution, path)
      File.open(path, "w") do |file|
        file.puts solution.map(&:last).count(&:any?)
        solution.each do |project, developers|
          next if developers.empty?
          file.puts project
          file.puts developers.join(" ")
        end
      end
    end
  end
end
