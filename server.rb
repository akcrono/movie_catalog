require 'pg'
require 'sinatra'
require 'sinatra/reloader'
require 'pry'

def db_connection
  begin
    connection = PG.connect(dbname: 'movies')

    yield(connection)

  ensure
    connection.close
  end
end

def get_movies(page, sort_by)
  db_connection do |conn|
    conn.exec("SELECT movies.id, movies.title, movies.year, movies.rating, genres.name AS genre, studios.name AS studio FROM movies
                JOIN genres ON genres.id = movies.genre_id
                JOIN studios ON studios.id = movies.studio_id
                ORDER BY movies.#{sort_by}
                LIMIT 20
                OFFSET #{(page.to_i-1)*20+1}")
  end
end

def get_actors(page)
  db_connection do |conn|
    conn.exec("SELECT count(cast_members.movie_id) AS movie_count, actors.name, actors.id FROM cast_members
          JOIN actors ON actors.id = cast_members.actor_id
          GROUP BY cast_members.actor_id, actors.name, actors.id
          ORDER BY actors.name
          LIMIT 20
          OFFSET #{(page.to_i-1)*20+1}")
  end
end

def get_movie movie_id
  db_connection do |conn|
    conn.exec('SELECT movies.title, genres.name AS genre, studios.name AS studio FROM movies
                JOIN genres ON genres.id = movies.genre_id
                JOIN studios ON studios.id = movies.studio_id
                WHERE movies.id = $1', [movie_id])
  end
end

def get_actor actor_id
  db_connection do |conn|
    conn.exec('SELECT name FROM actors
                WHERE id = $1', [actor_id])
  end
end

def get_actors_movies actor_id
  db_connection do |conn|
    conn.exec("SELECT movies.id, movies.title, cast_members.character FROM movies
              JOIN cast_members ON movies.id = cast_members.movie_id
              JOIN actors ON actors.id = cast_members.actor_id
            WHERE actors.id = $1
            ORDER BY movies.title", [actor_id])
  end
end

def get_movies_actors movie_id
  db_connection do |conn|
    conn.exec("SELECT actors.id, actors.name, cast_members.character FROM movies
              JOIN cast_members ON movies.id = cast_members.movie_id
              JOIN actors ON actors.id = cast_members.actor_id
            WHERE movies.id = $1
            ORDER BY actors.name", [movie_id])
  end
end

def search_movies search_term
    search_term = "%"+search_term+"%"
  db_connection do |conn|
    conn.exec('SELECT id, title FROM movies
                WHERE title ILIKE $1
                ORDER BY title', [search_term])
  end
end

def search_actors search_term
  search_term = "%"+search_term+"%"
  db_connection do |conn|
    conn.exec('SELECT DISTINCT actors.id, actors.name FROM actors
                JOIN cast_members ON cast_members.actor_id = actors.id
                WHERE actors.name ILIKE $1 OR cast_members.character ILIKE $1
                ORDER BY actors.name', [search_term])
  end
end



get '/' do
  erb :index
end

get '/movies' do
  if params[:page] != nil
    @page_number = params[:page]
  else
      @page_number = "1"
  end
  if params[:order] == 'year' || params[:order] == 'rating'
    @order = params[:order]
  else
      @order = 'title'
  end
  # binding.pry
  @movies = get_movies(@page_number, @order).to_a
  erb :'movies/index'
end

get '/movies/:id' do
  @movie_id = params[:id]
  @this_movie = get_movie(@movie_id).to_a
  @movies_actors = get_movies_actors(@movie_id)
  erb :'movies/show'
end

get '/actors' do
  if params[:page] != nil
    @page_number = params[:page]
  else
    @page_number = "1"
  end
  @actors = get_actors(@page_number).to_a
  erb :'actors/index'
end

get '/actors/:id' do
  @actor_id = params[:id]
  @this_actor = get_actor @actor_id
  @actors_movies = get_actors_movies @actor_id
  erb :'actors/show'
end

get '/search_actors' do
  @search = params[:search_results]
  @actors = search_actors(@search).to_a
  erb :'actors/search'
end

get '/search_movies' do
  @search = params[:search_results]
  @movies = search_movies(@search).to_a
  erb :'movies/search'
end
